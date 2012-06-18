

require File.expand_path(File.join(File.dirname(__FILE__),'grouped-experiment'))


module Experimoto
  
  class ABExperiment < GroupedExperiment
    
    def initialize(opts={})
      super(opts)
      @type = 'ABExperiment'
    end
    
    def _internal_sample
      total_weight = @groups.keys.map { |k| @group_split_weights[k] }.inject(0) {|a,b| a+b}
      current_weight = rand() * total_weight
      @groups.keys.each do |group_name|
        if current_weight < @group_split_weights[group_name]
          return group_name
        else
          current_weight -= @group_split_weights[group_name]
        end
      end
    end
    
  end
  
end
