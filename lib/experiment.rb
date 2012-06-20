

# $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'

require 'json'

require File.expand_path(File.join(File.dirname(__FILE__),'experiment-group'))
require File.expand_path(File.join(File.dirname(__FILE__),'utils'))


module Experimoto
  
  class Experiment
    
    attr_accessor :id, :type, :name, :data, :created_at, :modified_at
    
    def initialize(opts={})
      if opts.include?(:row)
        row = opts[:row]
        @id, @type, @name, @created_at, @modified_at, json_data = row
        @data = JSON.parse(json_data)
        # TODO: need to figure out if the dates are datetimes :/
      else
        raise ArgumentError, 'Experiment needs a name!' unless opts[:name].kind_of?(String)
        @id = opts[:id] || Utils.new_id
        @type = 'Experiment'
        @name = opts[:name]
        @created_at = opts[:created_at]
        @modified_at = opts[:modified_at]
        @data = opts[:data] || {}
        @data['description'] = opts[:description] if opts[:description]
      end
    end
    
    def description
      @data['description'] || ''
    end
    def description=x
      @data['description'] = x
    end
    
    def store_in_cookie?
      true
    end
    
    def is_view?
      false
    end
    
    def track?
      true
    end
    
    def sample
      'default'
    end
    
    def local_event(opts={})
    end
    
    def to_row
      # TODO: need to figure out if the dates are datetimes :/
      [@id, @type, @name, @created_at, @modified_at, JSON.unparse(@data)]
    end
    
    def to_hash
      { :id => @id, :type => @type, :name => @name,
        :created_at => @created_at, :modified_at => @modified_at,
        :data => @data }
    end
    
  end
  
end
