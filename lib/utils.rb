


require 'base64'

require 'rubygems'
require 'uuidtools'


module Experimoto
  module Utils
    def self.new_id
      uuid = UUIDTools::UUID.random_create
      Base64.encode64(uuid.raw)[0..-4].gsub('+','-').gsub('/','_')
    end
  end
end
