


require 'date'
require 'openssl'
require 'thread'
require 'set'

require 'rubygems'
require 'json'
require 'rdbi'

require File.expand_path(File.join(File.dirname(__FILE__),'event-stats'))
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
      handle = dbh
      handle.execute('create table if not exists experiments (' +
                     ['id char(22) primary key',
                      'type varchar(100)',
                      'name varchar(200)',
                      'created_at datetime',
                      'modified_at datetime',
                      'data text'
                     ].join(',') + ');')
      handle.execute('create table if not exists users (' +
                     ['id char(22) primary key',
                      'created_at datetime',
                      'modified_at datetime'
                     ].join(',') + ');')
      handle.execute('create table if not exists groupings (' +
                     ['id integer primary key autoincrement',
                      'uid char(22)',
                      'eid char(22)',
                      'group_name varchar(200)',
                      'created_at datetime',
                      'modified_at datetime'
                     ].join(',') + ');')
      handle.execute('create table if not exists events (' +
                     ['id integer primary key autoincrement',
                      'uid char(22)',
                      'eid char(22)',
                      'group_name varchar(200)',
                      'key varchar(200)',
                      'value double',
                      'created_at datetime',
                      'modified_at datetime'
                     ].join(',') + ');')
      EventStats.table_creation_statements.each { |stmt| handle.execute(stmt) }
      # indexes
      indexes = ['create unique index experiment_names on experiments(name asc);',
                 'create index user_created_at  on users(created_at  asc);',
                 'create index user_modified_at on users(modified_at asc);',
                 'create index grouping_eid_group on events(eid, group_name);',
                 'create index grouping_created_at  on groupings(created_at  asc);',
                 'create index grouping_modified_at on groupings(modified_at asc);',
                 'create index event_eid_group_key on events(eid, group_name, key);',
                 'create index event_created_at  on events(created_at  asc);',
                 'create index event_modified_at on events(modified_at asc);'
                ] + EventStats.index_creation_statements
      indexes.each do |ix|
        begin
          handle.execute(ix)
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
      experiment = nil
      @mutex.synchronize do
        experiment = @experiments[experiment_name]
      end
      return opts[:default] if experiment.nil?
      cached = false
      
      if experiment.is_view?
        output = user_experiment(user, experiment.target_experiment_name, opts)
        if experiment.json_lookup_index
          output = JSON.parse(output)[experiment.json_lookup_index]
        end
        return output
      end
      
      if user.groups.include?(experiment_name)
        # TODO: make sure group isn't deprecated?
        group_name = user.groups[experiment_name]
        cached = true
      end
      
      unless cached
        group_name = experiment.sample(:no_record => user.tester?)
        user.groups[experiment_name] = group_name
        unless user.tester?
          user_db_grouping!(user.id, experiment.id, group_name)
          user.modified_at = DateTime.now.to_s
        end
      end
      
      output = group_name
      
      if opts[:return_annotation] && experiment.group_annotations[group_name] && experiment.group_annotations[group_name].size > 1
        output = experiment.group_annotations[group_name]
      end
      
      output
    end
    
    def user_db_grouping!(uid, eid, group_name)
      handle = dbh
      date = DateTime.now.to_s
      handle.prepare('insert into groupings (uid, eid, group_name, created_at, modified_at) values (?,?,?,?,?)') do |sth|
        sth.execute(uid, eid, group_name, date, date)
      end
      handle.prepare('update users set modified_at = ? where id = ? and modified_at < ?') do |sth|
        sth.execute(date, uid, date)
      end
      EventStats.add_event_stat(handle, eid, group_name, '', 'play_count', 1)
    end
    
    def user_experiment_event(user, experiment_name, key, value=1)
      return if user.tester?
      
      group_name = user_experiment(user, experiment_name)
      
      experiment = nil
      @mutex.synchronize do
        experiment = @experiments[experiment_name]
        return if experiment.nil? || !experiment.track?
        experiment.local_event(:user => user, :group_name => group_name,
                               :key => key, :value => value)
      end
      
      handle = dbh
      handle.prepare('insert into events (uid, eid, group_name, key, value, created_at, modified_at) values (?,?,?,?,?,?,?)') do |sth|
        sth.execute(user.id, experiment.id, group_name, key, value,
                    DateTime.now.to_s, DateTime.now.to_s)
      end
      EventStats.add_event_stat(handle, experiment.id, group_name, key, 'value_sum', value)
      EventStats.add_event_stat(handle, experiment.id, group_name, key, 'value_squared_sum', value * value)
    end
    
    # trying to emulate vanity's track! function
    def track(user, key, value=1)
      user.groups.keys.each do |experiment_name|
        user_experiment_event(user, experiment_name, key, value)
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
    
    def user_from_cookie(cookie_hash = {}, db_user_id = nil)
      db_user_modified_at = nil
      user = nil
      
      if cookie_hash.include?('experimoto_data')
        begin
          # TODO: this needs to check that the cookie is well-formed
          # beyond just the mac (ie, in case of a browser with a
          # malformed cookie from a past bug)
          
          user = User.new(:cookie_hash => cookie_hash, :hmac_key => @hmac_key)
          
          db_user_id ||= user.id
        rescue
          # TODO: figure out a better way of handling malformed cookies :/
        end
      end
      
      if db_user_id
        dbh.prepare('select modified_at from users where id = ?') do |sth|
          sth.execute(db_user_id).each do |x|
            next if x.nil?
            db_user_modified_at = x[0]
            break
          end
        end
      end
      if (user && user.id != db_user_id) || (db_user_modified_at && db_user_modified_at > user.modified_at)
        dbh.prepare('select eid, group_name from groupings where uid = ? order by created_at asc') do |sth|
          sth.execute(db_user_id).each do |row|
            next if row.nil?
            eid = row[0]
            group_name = row[1]
            experiment = @experiments.values.find { |x| x.id == eid }
            if experiment
              user.groups[experiment.name] = group_name
            end
          end
        end
        user.id = db_user_id
        user.modified_at = db_user_modified_at
      end
      
      if user
        # clean out deprecated experiments and experiment-views
        @mutex.synchronize do
          user.groups.keys.each do |name|
            unless @experiments.include?(name) && @experiments[name].store_in_cookie?
              user.groups.delete(name)
            end
          end
        end
      else
        user = new_user_into_db
      end
      
      user
    end
    
    def user_to_cookie(user)
      user.to_cookie(@hmac_key)
    end
    
  end
  
end
