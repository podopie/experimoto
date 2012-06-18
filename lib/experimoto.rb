


require 'date'
require 'openssl'
require 'thread'

require 'rubygems'
require 'json'

require File.expand_path(File.join(File.dirname(__FILE__),'experiment'))
require File.expand_path(File.join(File.dirname(__FILE__),'ucb1-experiment'))
require File.expand_path(File.join(File.dirname(__FILE__),'ab-experiment'))
require File.expand_path(File.join(File.dirname(__FILE__),'syncing-thread'))
require File.expand_path(File.join(File.dirname(__FILE__),'experiment-view'))
require File.expand_path(File.join(File.dirname(__FILE__),'user'))
require File.expand_path(File.join(File.dirname(__FILE__),'utils'))


module Experimoto
  
  class Experimoto
    
    attr_accessor :experiments, :hmac_key
    
    attr_reader :mutex, :synced, :generated_tables, :dbh
    
    def initialize(opts={})
      @experiments = {} # mapping experiment id to experiment
      @hmac_key = '' # TODO: configuration
      @dbh = opts[:dbh]
      @generated_tables = false
      @synced = false
      @mutex = Mutex.new
      @syncing_thread = nil
    end
    
    def start_syncing_thread(opts={})
      stop_syncing_thread
      @syncing_thread = SyncingThread.new(opts)
    end
    def stop_syncing_thread
      @syncing_thread.stop if @syncing_thread
    end
    
    def generate_tables
      @dbh.execute('create table if not exists experiments (' +
                   ['id char(22) primary key',
                    'type varchar(100)',
                    'name varchar(200)',
                    'created_at datetime',
                    'modified_at datetime',
                    'data text'
                   ].join(',') + ');')
      @dbh.execute('create table if not exists users (' +
                   ['id char(22) primary key',
                    'created_at datetime',
                    'modified_at datetime'
                   ].join(',') + ');')
      @dbh.execute('create table if not exists groupings (' +
                   ['id integer primary key autoincrement',
                    'uid char(22)',
                    'eid char(22)',
                    'group_name char(200)',
                    'created_at datetime',
                    'modified_at datetime'
                   ].join(',') + ');')
      @dbh.execute('create table if not exists events (' +
                   ['id integer primary key autoincrement',
                    'uid char(22)',
                    'eid char(22)',
                    'group_name char(200)',
                    'key varchar(200)',
                    'value integer',
                    'created_at datetime',
                    'modified_at datetime'
                   ].join(',') + ');')
      # TODO: indexes
      @generated_tables = true
    end

    def experiment_type_to_class(type)
      case type
      when 'ABExperiment' ; ABExperiment
      when 'UCB1Experiment' ; UCB1Experiment
      when 'ExperimentView' ; ExperimentView
      else
        raise 'invalid experiment type'
      end
    end
    
    def db_sync
      @mutex.synchronize { _db_sync }
    end
    def _db_sync
      generate_tables unless @generated_tables
      
      #acquire experiments
      db_experiments = @dbh.execute('select * from experiments;'
                                    ).to_a.find_all { |row| !row.nil? }.map do |row|
        type = row[1]
        opts = {:row => row, :dbh => @dbh}
        
        experiment_type_to_class(type).new(opts)
      end
      
      # TODO: insert any experiments from our config file if they're
      # not already present in db?
      
      db_experiments.each do |x|
        @experiments[x.name] = x
      end
      
      @synced = true
    end
    
    def add_new_experiment(opts)
      if opts[:multivariate]
        opts[:experiments] # a hash of names to arrays of group names
        
        groups_list = opts[:experiments].keys.sort.map { |k| opts[:experiments][k] }
        opts[:groups] = groups_list[0].product(*groups_list.drop(1)).map do |l|
          JSON.unparse(l)
        end
        
        # TODO: assert that the type is a grouped type?
      end
      
      exp = experiment_type_to_class(opts[:type]).new(opts)
      @dbh.prepare('insert into experiments values (?,?,?,?,?,?);') do |sth|
        sth.execute(*exp.to_row)
      end
      
      db_sync
      
      if opts[:multivariate]
        opts[:experiments].keys.sort.zip(opts[:experiments].size.times.to_a).each do |ename, ix|
          add_new_experiment(:name => ename, :type => 'ExperimentView',
                             :target_experiment_name => opts[:name],
                             :json_lookup_index => ix)
        end
      end
      
      d_exp = @experiments[exp.name]
      # TODO: somehow assert that  exp.to_row == d_exp.to_row (just for safety purposes)
      d_exp
    end
    
    def user_experiment(user, experiment_name)
      experiment = nil
      @mutex.synchronize do 
        experiment = @experiments[experiment_name]
        raise "no such experiment, `#{experiment_name}`!" if experiment.nil?
      end
      
      if experiment.is_view?
        group_name = user_experiment(user, experiment.target_experiment_name)
        if experiment.json_lookup_index
          group_name = JSON.parse(group_name)[experiment.json_lookup_index]
        end
        return group_name
      end
      
      if user.groups.include?(experiment_name)
        # TODO: make sure group isn't deprecated?
        return user.groups[experiment_name]
      end
      
      @mutex.synchronize do
        experiment = @experiments[experiment_name]
        raise "no such experiment, `#{experiment_name}`!" if experiment.nil?
        group_name = experiment.sample(:no_record => user.tester?)
      end
      
      user.groups[experiment_name] = group_name
      unless user.tester?
        @dbh.prepare('insert into groupings (uid, eid, group_name, created_at, modified_at) values (?,?,?,?,?)') do |sth|
          sth.execute(user.id, experiment.id, group_name, DateTime.now, DateTime.now)
        end
      end
      
      group_name
    end
    
    def user_experiment_event(user, experiment_name, key, value=1)
      experiment = nil
      @mutex.synchronize { experiment = @experiments[experiment_name] }
      return if experiment.nil?
      if experiment.is_view?
        # giant warning: if multiple views point to the same
        # experiment, calling user_experiment_event on it will cause
        # duplicates.
        return user_experiment_event(user, experiment.target_experiment_name, key, value)
      end
      
      group_name = user_experiment(user, experiment_name)
      unless user.tester?
        @dbh.prepare('insert into events (uid, eid, group_name, key, value, created_at, modified_at) values (?,?,?,?,?,?,?)') do |sth|
          sth.execute(user.id, experiment.id, group_name, key, value,
                      DateTime.now, DateTime.now)
        end
        experiment.local_event(:user => user, :group_name => group_name,
                               :key => key, :value => value)
      end
    end
    
    # trying to emulate vanity's track! function
    def track(user, key, value=1)
      user.groups.keys.each do |experiment_name|
        experiment = nil
        @mutex.synchronize { experiment = @experiments[experiment_name] }
        next if experiment.nil?
        next unless experiment.track?
        user_experiment_event(user, experiment_name, key, value)
      end
    end
    
    def new_user_into_db(opts={})
      u = new_user(opts)
      write_user_to_db(u)
      u
    end
    
    def write_user_to_db(user)
      @dbh.prepare('insert into users values (?,?,?)') do |sth|
        sth.execute(*user.to_row)
      end
    end
    
    def new_user(opts={})
      User.new(opts.merge(:experimoto => self))
    end
    
    def user_from_cookie(cookie_hash = {}, user = nil)
      
      if cookie_hash.include?('experimoto_data')
        begin
          # TODO: this needs to check that the cookie is well-formed
          # beyond just the mac (ie, in case of a browser with a
          # malformed cookie from a past bug)
          
          user = User.new(:cookie_hash => cookie_hash, :hmac_key => @hmac_key)
          
          # clean out deprecated experiments and experiment-views
          @mutex.synchronize do
            user.groups.keys.each do |name|
              unless @experiments.include?(name) && @experiments[name].store_in_cookie?
                user.groups.delete(name)
              end
            end
          end
        rescue
          # TODO: figure out a better way of handling malformed cookies :/
        end
      end
      
      user = new_user_into_db if user.nil?
      
      user
    end
    
    def user_to_cookie(user)
      user.to_cookie(@hmac_key)
    end
    
  end
  
end
