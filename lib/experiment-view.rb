
require File.expand_path(File.join(File.dirname(__FILE__),'experiment'))

module Experimoto
  
  class ExperimentView < Experiment
    
    attr_accessor :target_experiment_name, :json_lookup_index
    
    def initialize(opts={})
      super(opts)
      @type = 'ExperimentView'
      @target_experiment_name = opts[:target_experiment_name] || @data['target_experiment_name']
      @json_lookup_index = opts[:json_lookup_index] || @data['json_lookup_index']
    end
    
    def store_in_cookie?
      false
    end
    
    def is_view?
      true
    end
    
    def track?
      false
    end
    
    def sample
      raise NotImplementedError
    end
    
    def local_event(opts={})
      raise NotImplementedError
    end
    
    def to_row
      @data['target_experiment_name'] = @target_experiment_name
      @data['json_lookup_index'] = @json_lookup_index
      super
    end
    
  end
  
end
