

require File.expand_path(File.join(File.dirname(__FILE__),'grouped-experiment'))


module Experimoto
  
  class ABExperiment < GroupedExperiment
    
    def initialize(opts={})
      super(opts)
      @type = 'ABExperiment'
    end
    
    def _internal_sample
      # assuming even split for now
      @groups.keys[rand(groups.size)]
    end
    
  end
  
end
