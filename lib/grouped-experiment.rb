
require 'rubygems'
require 'json'

require File.expand_path(File.join(File.dirname(__FILE__),'experiment'))
require File.expand_path(File.join(File.dirname(__FILE__),'experiment-group'))


module Experimoto
  
  class GroupedExperiment < Experiment
    
    attr_accessor :groups, :plays
    
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
      
    end
    
    def add_group(opts)
      @groups[opts[:name]] = ExperimentGroup.new(opts)
      init_event_total_for_group(opts[:name])
    end
    
    def init_event_total_for_group(group_name)
      @event_totals[group_name] = {}
      @event_totals[group_name].default = 0
    end
    
    def init_event_totals
      @event_totals = {}
      @groups.keys.each do |group_name|
        init_event_total_for_group(group_name)
      end
    end
    
    def utility_function_string
      @data['utility_function'] || 'success'
    end
    def utility_function_string=(x)
      @data['utility_function'] = x
    end
    def utility_function_variables
      utility_function_string.scan(/[A-z_][0-9A-z_]*/).uniq.sort
    end
    
    def utility(group_name)
      expr = utility_function_string
      utility_function_variables.each do |k|
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
        @groups = Hash[arr.map { |g| [g.name, g] }]
      elsif opts.include?(:groups) && opts[:groups].kind_of?(Hash)
        @groups = opts[:groups]
      else
        @groups = {'default' => ExperimentGroup.new(:name => 'default')}
      end
      
      init_event_totals
      
      @data['utility_function'] = opts[:utility_function]
    end
    
    def initialize_grouped_experiment_from_db(opts)
      raise 'hell' unless opts[:dbh]
      
      json_friendly_groups = @data['groups']
      @groups = {}
      json_friendly_groups.each do |k,v|
        @groups[k] = ExperimentGroup.new(v)
      end
      
      init_event_totals
      
      dbh = opts[:dbh]
      # plays
      dbh.prepare('select eid, group_name, count(*) from groupings where eid = ? and group_name = ?;') do |sth|
        @groups.keys.each do |name|
          sth.execute(@id, name).each do |row|
            next if row.nil?
            @plays[name] = row[2]
            break
          end
        end
      end
      # utility information
      dbh.prepare('select eid, group_name, sum(value) from events where eid = ? and group_name = ? and key = ?;') do |sth|
        @groups.keys.each do |group_name|
          utility_function_variables.each do |event_name|
            sth.execute(@id, group_name, event_name).each do |row|
              next if row.nil?
              val = row[2].nil? ? 0 : row[2]
              @event_totals[group_name][event_name] = val.to_i
              break
            end
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
    
    def to_row
      json_friendly_groups = {}
      groups.each do |k,v|
        json_friendly_groups["#{k}"] = v.json_friendly
      end
      @data['groups'] = json_friendly_groups
      super
    end
    
  end
  
end
