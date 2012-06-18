
require 'json'

require File.expand_path(File.join(File.dirname(__FILE__),'utils'))


module Experimoto
  
  class ExperimentGroup
    
    attr_accessor :name
    
    def initialize(opts={})
      opts = opts.clone
      opts.keys.each do |k|
        opts[k.to_sym] = opts[k]
      end 
      raise 'Experiment group needs a name!' unless opts.include?(:name)
      @name = opts[:name]
    end
    
    def json_friendly
      {'name' => @name}
    end
    
  end
  
end
