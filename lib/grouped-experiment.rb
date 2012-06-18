
require 'rubygems'
require 'json'

require File.expand_path(File.join(File.dirname(__FILE__),'experiment'))
require File.expand_path(File.join(File.dirname(__FILE__),'experiment-group'))


module Experimoto
  
  class GroupedExperiment < Experiment
    
    attr_accessor :plays
    
    def initialize(opts={})
      super(opts)
      
      # cached info on usage; this doesn't get written back to db directly.
      @plays = {} # map from group name to # of times a user has gotten that group
      @plays.default = 0
      
      if opts[:row]
        initialize_grouped_experiment_from_db(opts)
      else
        initialize_grouped_experiment_from_args(opts)
      end
      
      self.group_split_weights ||= {}
      self.group_split_weights.default = 1.0
      self.group_split_weights.merge!(opts[:group_split_weights]) if opts[:group_split_weights]
    end
    
    def group_split_weights
      @data['group_split_weights']
    end
    def group_split_weights=x
      @data['group_split_weights'] = x
    end
    
    def groups
      @data['groups']
    end
    def groups=x
      @data['groups'] = x
    end
    
    def add_group(opts)
      self.groups[opts[:name]] = ExperimentGroup.new(opts)
      init_event_total_for_group(opts[:name])
    end
    
    def init_event_total_for_group(group_name)
      @event_totals[group_name] = {}
      @event_totals[group_name].default = 0
    end
    
    def init_event_totals
      @event_totals = {}
      self.groups.keys.each do |group_name|
        init_event_total_for_group(group_name)
      end
    end
    
    def utility_function_string
      @data['utility_function'] || 'success'
    end
    def utility_function_string=(x)
      @data['utility_function'] = x
    end
    def utility_function_variables(s=nil)
      s ||= utility_function_string
      s.scan(/[A-z_][0-9A-z_]*/).uniq.sort
    end
    
    def utility(group_name, given_utility_function = nil, dbh = nil)
      expr = given_utility_function || utility_function_string
      if given_utility_function
        raise 'hell' if dbh.nil?
        sync_play_data(dbh)
        utility_function_variables(expr).each do |k|
          sync_event_data(dbh, k)
        end
      end
      utility_function_variables(expr).each do |k|
        if 0 == @plays[group_name]
          avg = 0
        else
          avg = (1.0 * (@event_totals[group_name][k])) / @plays[group_name]
        end
        expr = expr.gsub(k, "(#{avg})")
      end
      unless(0 == expr.gsub(/[0-9\+\-\*\/\(\)\.]/,'').size &&
             expr.count('(') == expr.count(')'))
        raise "invalid utility function: `#{expr}`"
      end
      eval('('+expr+')')
    end
    
    def initialize_grouped_experiment_from_args(opts)
      if opts.include?(:groups) && opts[:groups].kind_of?(Array)
        arr = opts[:groups].map do |g|
          if g.kind_of?(ExperimentGroup)
            g
          else
            ExperimentGroup.new(:name => g)
          end
        end
        self.groups = Hash[arr.map { |g| [g.name, g] }]
      elsif opts.include?(:groups) && opts[:groups].kind_of?(Hash)
        self.groups = opts[:groups]
      elsif @data.include?('groups')
      else
        self.groups = {'default' => ExperimentGroup.new(:name => 'default')}
      end
      
      init_event_totals
      
      if opts[:utility_function]
        @data['utility_function'] = opts[:utility_function]
      end
    end
    
    def initialize_grouped_experiment_from_db(opts)
      raise 'hell' unless opts[:dbh]
      
      init_event_totals
      
      dbh = opts[:dbh]
      # plays
      sync_play_data(dbh)
      # utility information
      utility_function_variables.each do |event_name|
        sync_event_data(dbh, event_name)
      end
    end
    
    def sync_play_data(dbh)
      dbh.prepare('select eid, group_name, count(*) from groupings where eid = ? and group_name = ?;') do |sth|
        self.groups.keys.each do |name|
          sth.execute(@id, name).each do |row|
            next if row.nil?
            @plays[name] = row[2]
            break
          end
        end
      end
    end
    
    def sync_event_data(dbh, event_name)
      dbh.prepare('select eid, group_name, sum(value) from events where eid = ? and group_name = ? and key = ?;') do |sth|
        self.groups.keys.each do |group_name|
          sth.execute(@id, group_name, event_name).each do |row|
            next if row.nil?
            val = row[2].nil? ? 0 : row[2]
            @event_totals[group_name][event_name] = val.to_i
            break
          end
        end
      end
    end
    
    def sample(opts={})
      result = _internal_sample
      @plays[result] += 1 unless opts[:no_record]
      result
    end
    def local_event(opts)
      @event_totals[opts[:group_name]][opts[:key]] += opts[:value]
    end
    
    def _internal_sample
      'default'
    end
    
  end
  
end
