
require 'date'
require 'openssl'
require 'uri'

require 'rubygems'
require 'json'

require File.expand_path(File.join(File.dirname(__FILE__),'utils'))


module Experimoto
  
  class User
    
    attr_accessor :id, :groups, :created_at, :modified_at, :is_tester
    
    def initialize(opts={})
      if opts[:cookie_hash]
        puts 'from cookie'
        import_from_cookie(opts[:cookie_hash], opts[:hmac_key], opts[:ignore_hmac])
      else
        @id = opts[:id] || Utils.new_id
        @groups = opts[:groups] || {} # mapping of experiment name to group name
        @created_at = opts[:created_at] || DateTime.now.to_s
        @modified_at = opts[:modified_at] || DateTime.now.to_s
        @is_tester = true == opts[:is_tester]
      end
      if @created_at.kind_of?(String)
        @created_at = DateTime.parse(@created_at)
      end
    end
    
    def tester?
      @is_tester
    end
    
    def to_row
      [@id, @created_at, @modified_at]
    end
    
    def to_json
      base = { 'id' => @id, 'groups' => @groups, 'date' => @modified_at }
      base['is_tester'] = true if tester?
      JSON.unparse(base)
    end
    
    def to_cookie(hmac_key)
      data = self.to_json
      mac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('sha1'),
                                    hmac_key, data)
      {'experimoto_data' => URI.escape(data),
        'experimoto_mac' => URI.escape(mac)}
    end
    
    def import_from_cookie(cookie_hash, hmac_key, ignore_hmac = false)
      data = URI.unescape(cookie_hash['experimoto_data'])
      unless ignore_hmac
        mac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('sha1'),
                                      hmac_key, data)
        raise 'hell' if mac != URI.unescape(cookie_hash['experimoto_mac'])
      end
      from_json(JSON.parse(data))
    end
    
    def from_json(h)
      @id = h['id']
      @groups = h['groups']
      @created_at = nil
      @modified_at = h['date']
      @is_tester = true == h['is_tester']
    end
    
  end
  
end
