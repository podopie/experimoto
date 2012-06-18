
require File.expand_path(File.join(File.dirname(__FILE__),'experiment'))

module Experimoto
  
  class ExperimentView < Experiment
    
    def initialize(opts={})
      super(opts)
      @type = 'ExperimentView'
      self.target_experiment_name = opts[:target_experiment_name] if opts[:target_experiment_name]
      self.json_lookup_index = opts[:json_lookup_index] if opts[:json_lookup_index]
    end
    
    def target_experiment_name
      @data['target_experiment_name']
    end
    def target_experiment_name=x
      @data['target_experiment_name'] = x
    end
    def json_lookup_index
      @data['json_lookup_index']
    end
    def json_lookup_index=x
      @data['json_lookup_index'] = x
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
    
  end
  
end
