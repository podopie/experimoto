


require 'date'
require 'openssl'
require 'thread'
require 'set'

require 'rubygems'
require 'json'
require 'rdbi'

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
    
    attr_reader :mutex, :synced, :generated_tables, :dbh, :syncing_thread
    
    def initialize(opts={})
      @experiments = {} # mapping experiment id to experiment
      @hmac_key = '' # TODO: configuration
      @dbh = opts[:dbh]
      @rdbi_args = opts[:rdbi_args]
      raise ArgumentError unless @dbh || @rdbi_args
      @generated_tables = false
      @synced = false
      @mutex = Mutex.new
      @syncing_thread = nil
    end
    
    def dbh
      return @dbh if @dbh
      RDBI.connect(*@rdbi_args)
    end
    
    def start_syncing_thread(opts={})
      @mutex.synchronize do
        stop_syncing_thread(:no_sync => true)
        @syncing_thread = SyncingThread.new(self, opts)
      end
    end
    
    def stop_syncing_thread(opts={})
      if opts[:no_sync]
        @syncing_thread.stop if @syncing_thread
      else
        @mutex.synchronize do
          @syncing_thread.stop if @syncing_thread
        end
      end
    end
    
    def generate_tables
      dbh.execute('create table if not exists experiments (' +
                   ['id char(22) primary key',
                    'type varchar(100)',
                    'name varchar(200)',
                    'created_at datetime',
                    'modified_at datetime',
                    'data text'
                   ].join(',') + ');')
      dbh.execute('create table if not exists users (' +
                   ['id char(22) primary key',
                    'created_at datetime',
                    'modified_at datetime'
                   ].join(',') + ');')
      dbh.execute('create table if not exists groupings (' +
                   ['id integer primary key autoincrement',
                    'uid char(22)',
                    'eid char(22)',
                    'group_name varchar(200)',
                    'created_at datetime',
                    'modified_at datetime'
                   ].join(',') + ');')
      dbh.execute('create table if not exists events (' +
                   ['id integer primary key autoincrement',
                    'uid char(22)',
                    'eid char(22)',
                    'group_name varchar(200)',
                    'key varchar(200)',
                    'value double',
                    'created_at datetime',
                    'modified_at datetime'
                   ].join(',') + ');')
      # TODO: indexes
      indexes = ['create unique index experiment_names on experiments(name asc);',
                 'create index user_created_at  on users(created_at  asc);',
                 'create index user_modified_at on users(modified_at asc);',
                 'create index grouping_eid_group on events(eid, group_name);',
                 'create index grouping_created_at  on groupings(created_at  asc);',
                 'create index grouping_modified_at on groupings(modified_at asc);',
                 'create index event_eid_group_key on events(eid, group_name, key);',
                 'create index event_created_at  on events(created_at  asc);',
                 'create index event_modified_at on events(modified_at asc);',
                ]
      indexes.each do |ix|
        begin
          dbh.execute(ix)
        rescue SQLite3::SQLException
          # NOTE: mysql might not support create index if not exists,
          # so just gonna have to rescue a lot of exceptions.
        end
      end
      @generated_tables = true
    end

    def experiment_type_to_class(type)
      case type
      when 'ABExperiment' ; ABExperiment
      when 'UCB1Experiment' ; UCB1Experiment
      when 'ExperimentView' ; ExperimentView
      else
        raise ArgumentError, 'invalid experiment type'
      end
    end
    
    def db_sync(opts={})
      generate_tables unless @generated_tables
      
      #acquire experiments
      db_experiments = dbh.execute('select * from experiments;'
                                   ).to_a.find_all { |row| !row.nil? }.map do |row|
        type = row[1]
        exp_opts = {:row => row, :dbh => dbh}
        
        experiment_type_to_class(type).new(exp_opts)
      end
      
      # TODO: insert any experiments from our config file if they're
      # not already present in db?
      
      set_exps = lambda do
        @experiments = {}
        db_experiments.each do |x|
          @experiments[x.name] = x
        end
        @synced = true
      end
      
      if opts[:already_locked]
        set_exps.call
      else
        @mutex.synchronize { set_exps.call }
      end
    end
    
    def save_experiment(opts)
      if opts[:name].kind_of?(String)
        experiment = nil
        @mutex.synchronize { experiment = @experiments[opts[:name]] }
        return if experiment.nil?
      elsif opts[:experiment].kind_of?(Experiment)
        experiment = opts[:experiment]
      else
        raise ArgumentError
      end
      
      dbh.prepare('update experiments set type = ?, name = ?, modified_at = ?, data = ? where id = ?;') do |sth|
        row0 = experiment.to_row
        row = row0.clone
        row.delete_at(0)
        row.delete_at(2)
        sth.execute(row + [row0[0]])
      end
      
      db_sync
      @mutex.synchronize { @experiments[experiment.name] }
    end
    
    def delete_experiment(experiment_name, opts={})
      @mutex.synchronize { _delete_experiment(experiment_name, opts) }
    end
    def _delete_experiment(experiment_name, opts={})
      return unless @experiments.include?(experiment_name)
      to_delete = Set.new
      to_delete.add(experiment_name)
      
      n0 = nil
      n1 = to_delete.size
      until n0 == n1
        @experiments.values.each do |x|
          if x.is_view? && to_delete.include?(x.target_experiment_name)
            to_delete.add(x.name)
          end
        end
        n0 = n1
        n1 = to_delete.size
      end
      
      dbh.prepare('delete from experiments where name = ?') do |sth|
        to_delete.to_a.each do |name|
          sth.execute(name)
        end
      end
      
      db_sync(:already_locked => true)
    end
    
    def add_new_experiment(opts)
      raise ArgumentError, 'option hash needs :type' unless opts[:type].kind_of?(String)
      raise ArgumentError, 'option hash needs :name' unless opts[:name].kind_of?(String)
      raise ArgumentError, 'experiment names need to match /\A[A-z0-9_]+\z/' unless opts[:name] =~ /\A[A-z0-9_]+\z/
      
      if opts[:multivariate]
        # a hash of names to arrays of group names
        unless opts[:experiments].kind_of?(Hash)
          raise ArgumentError, 'option hash needs a hash called :experiments, mapping sub-experiment names to arrays of sub-groups, to go with :multivariate'
        end
        sub_experiments = opts[:experiments].keys.sort
        raise ArgumentError, 'need >= 2 sub-experiments' unless opts[:experiments].size >= 2
        groups_list = sub_experiments.map { |k| opts[:experiments][k] }
        opts[:groups] = groups_list[0].product(*groups_list.drop(1)).map do |l|
          l.each { |k| raise ArgumentError, "#{k}" unless k.kind_of?(String) }
          JSON.unparse(l)
        end
        opts[:sub_experiments] = sub_experiments
        # TODO: assert that the type is a grouped type?
      end
      
      exp = experiment_type_to_class(opts[:type]).new(opts)
      dbh.prepare('insert into experiments values (?,?,?,?,?,?);') do |sth|
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
    
    def replace_experiment(opts)
      raise ArgumentError, 'option hash needs :type' unless opts[:type].kind_of?(String)
      raise ArgumentError, 'option hash needs :name' unless opts[:name].kind_of?(String)
      raise ArgumentError, 'experiment names need to match /\A[A-z0-9_]+\z/' unless opts[:name] =~ /\A[A-z0-9_]+\z/
      exp = experiment_type_to_class(opts[:type]).new(opts)
      save_experiment(:experiment => exp)
    end
    
    def rails_sample(cookies, experiment_name, opts = {})
      experiment_name = "#{experiment_name}" # in case people like symbols
      c = {'experimoto_mac' => cookies['experimoto_mac'], 'experimoto_data' => cookies['experimoto_data'] }
      user = self.user_from_cookie(c)
      sample = user_experiment(user, experiment_name, opts)
      c = user_to_cookie(user)
      c.each { |k,v| cookies[k] = v }
      sample
    end
    
    def rails_track(cookies, key, value = 1)
      c = {'experimoto_mac' => cookies['experimoto_mac'], 'experimoto_data' => cookies['experimoto_data'] }
      user = self.user_from_cookie(c)
      track(user, key, value)
    end
    
    def user_experiment(user, experiment_name, opts = {})
      @mutex.synchronize do
        _user_experiment(user, experiment_name, opts)
      end
    end
    
    def _user_experiment(user, experiment_name, opts = {})
      experiment = @experiments[experiment_name]
      return opts[:default] if experiment.nil?
      
      if experiment.is_view?
        group_name = _user_experiment(user, experiment.target_experiment_name, opts)
        if experiment.json_lookup_index
          group_name = JSON.parse(group_name)[experiment.json_lookup_index]
        end
        return group_name
      end
      
      if user.groups.include?(experiment_name)
        # TODO: make sure group isn't deprecated?
        return user.groups[experiment_name]
      end
      
      group_name = experiment.sample(:no_record => user.tester?)
      user.groups[experiment_name] = group_name
      unless user.tester?
        dbh.prepare('insert into groupings (uid, eid, group_name, created_at, modified_at) values (?,?,?,?,?)') do |sth|
          sth.execute(user.id, experiment.id, group_name, DateTime.now.to_s, DateTime.now.to_s)
        end
      end
      
      group_name
    end
    
    def user_experiment_event(user, experiment_name, key, value=1)
      @mutex.synchronize do
        _user_experiment_event(user, experiment_name, key, value)
      end
    end
    def _user_experiment_event(user, experiment_name, key, value=1)
      experiment = @experiments[experiment_name]
      return if experiment.nil?
      if experiment.is_view?
        # giant warning: if multiple views point to the same
        # experiment, calling user_experiment_event on it will cause
        # duplicates.
        return _user_experiment_event(user, experiment.target_experiment_name, key, value)
      end
      
      group_name = _user_experiment(user, experiment_name)
      unless user.tester?
        dbh.prepare('insert into events (uid, eid, group_name, key, value, created_at, modified_at) values (?,?,?,?,?,?,?)') do |sth|
          sth.execute(user.id, experiment.id, group_name, key, value,
                      DateTime.now.to_s, DateTime.now.to_s)
        end
        experiment.local_event(:user => user, :group_name => group_name,
                               :key => key, :value => value)
      end
    end
    
    # trying to emulate vanity's track! function
    def track(user, key, value=1)
      @mutex.synchronize do
        user.groups.keys.each do |experiment_name|
          experiment = @experiments[experiment_name]
          next if experiment.nil?
          next unless experiment.track?
          _user_experiment_event(user, experiment_name, key, value)
        end
      end
    end
    
    def new_user_into_db(opts={})
      u = User.new(opts)
      write_user_to_db(u)
      u
    end
    
    def write_user_to_db(user)
      dbh.prepare('insert into users values (?,?,?)') do |sth|
        sth.execute(*user.to_row)
      end
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
