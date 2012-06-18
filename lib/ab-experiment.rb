

require File.expand_path(File.join(File.dirname(__FILE__),'grouped-experiment'))


module Experimoto
  
  class ABExperiment < GroupedExperiment
    
    attr_accessor :group_split_weights
    
    def initialize(opts={})
      super(opts)
      @type = 'ABExperiment'
      
      @group_split_weights = {}
      @group_split_weights.default = 1.0
      if @data['group_split_weights']
        @group_split_weights.merge!(@data['group_split_weights'])
      end
      if opts[:group_split_weights]
        @group_split_weights.merge!(opts[:group_split_weights])
      end
    end
    
    def _internal_sample
      if @group_split_weights
        total_weight = @groups.keys.map { |k| @group_split_weights[k] }.inject(0) {|a,b| a+b}
        #puts total_weight
        current_weight = rand() * total_weight
        @groups.keys.each do |group_name|
          if current_weight < @group_split_weights[group_name]
            return group_name
          else
            current_weight -= @group_split_weights[group_name]
          end
        end
      else
        # even split
        @groups.keys[rand(groups.size)]
      end
    end
    
    def to_row
      @data['group_split_weights'] = @group_split_weights
      super
    end
    
  end
  
end
