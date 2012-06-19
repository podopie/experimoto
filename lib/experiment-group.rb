
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
    
    def to_json(*a)
      { 'json_class' => self.class.name, 'name' => @name }.to_json(*a)
    end
    
    def self.json_create(o)
      new(o)
    end
    
    def ==x
      @name == x.name
    end
    
  end
  
end
