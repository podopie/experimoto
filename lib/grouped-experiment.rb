
require 'rubygems'
require 'json'

require File.expand_path(File.join(File.dirname(__FILE__),'experiment'))
require File.expand_path(File.join(File.dirname(__FILE__),'experiment-group'))


module Experimoto
  
  class GroupedExperiment < Experiment
    
    attr_accessor :plays, :event_totals
    
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
      self.group_annotations ||= {}
      self.group_annotations.default = ''
      self.group_annotations.merge!(opts[:group_annotations]) if opts[:group_annotations]
    end
    
    def total_plays(plays=nil)
      plays ||= @plays
      plays.values.inject(0) { |a, b| a + b }
    end
    
    def group_split_weights
      @data['group_split_weights']
    end
    def group_split_weights=x
      @data['group_split_weights'] = x
    end
    
    def group_annotations
      @data['group_annotations']
    end
    def group_annotations=x
      @data['group_annotations'] = x
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
    
    def utility(group_name, opts = {})
      opts = opts.clone
      given_utility_function = opts.delete(:utility_function)
      dbh = opts.delete(:dbh)
      start_date = opts.delete(:start_date)
      end_date = opts.delete(:end_date)
      raise ArgumentError unless opts.empty?
      
      expr = given_utility_function || utility_function_string
      plays = @plays
      event_totals = @event_totals
      if given_utility_function || start_date || end_date
        raise ArgumentError if dbh.nil?
        raise ArgumentError if start_date && !end_date
        raise ArgumentError if !start_date && end_date
        if start_date
          start_date = start_date.to_s
          end_date = end_date.to_s
        end
        plays = {}
        event_totals = {}
        self.groups.keys.each do |name|
          event_totals[name] = {}
          event_totals[name].default = 0
        end

        sync_play_data(dbh, :plays => plays,
                       :start_date => start_date, :end_date => end_date)
        utility_function_variables(expr).each do |k|
          sync_event_data(dbh, k, :event_totals => event_totals,
                          :start_date => start_date, :end_date => end_date)
        end
      end
      utility_function_variables(expr).each do |k|
        if 0 == plays[group_name]
          avg = 0.0
        else
          avg = (1.0 * (event_totals[group_name][k])) / plays[group_name]
        end
        expr = expr.gsub(k, "(#{avg})")
      end
      unless(0 == expr.gsub(/[0-9+\-*\/()\. ]/,'').size && expr.count('(') == expr.count(')'))
        raise ArgumentError, "invalid utility function: `#{expr}`"
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
      elsif opts.include?(:groups)
        raise ArgumentError
      elsif @data.include?('groups')
      else
        self.groups = {'default' => ExperimentGroup.new(:name => 'default')}
      end
      
      init_event_totals
      
      if opts[:utility_function]
        self.utility_function_string = opts[:utility_function]
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
    
    def sync_play_data(dbh, opts={})
      plays = opts[:plays] || @plays
      sql = 'select eid, group_name, count(*) from groupings where eid = ? and group_name = ?'
      if opts[:start_date] && opts[:end_date]
        sql += ' and created_at >= ? and created_at < ?'
      end
      dbh.prepare(sql + ';') do |sth|
        self.groups.keys.each do |name|
          sql_args = [@id, name]
          if opts[:start_date] && opts[:end_date]
            sql_args << opts[:start_date].to_s
            sql_args << opts[:end_date].to_s
          end
          sth.execute(*sql_args).each do |row|
            next if row.nil?
            plays[name] = row[2]
            break
          end
        end
      end
    end
    
    def sync_event_data(dbh, event_name, opts={})
      event_totals = opts[:event_totals] || @event_totals
      sql = 'select eid, group_name, sum(value) from events where eid = ? and group_name = ? and key = ?'
      if opts[:start_date] && opts[:end_date]
        sql += ' and created_at >= ? and created_at < ?'
      end
      dbh.prepare(sql + ';') do |sth|
        self.groups.keys.each do |group_name|
          sql_args = [@id, group_name, event_name]
          if opts[:start_date] && opts[:end_date]
            sql_args << opts[:start_date]
            sql_args << opts[:end_date]
          end
          sth.execute(*sql_args).each do |row|
            next if row.nil?
            val = row[2].nil? ? 0 : row[2]
            event_totals[group_name][event_name] = val.to_f
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
