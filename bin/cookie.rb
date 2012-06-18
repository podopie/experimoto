
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','experimoto'))

require 'optparse'


def reshape_cookies(opts={})
  hmac_key = '' # TODO: configuration!
  cookie_string = opts[:original_cookie_string] || ''
  cookies = cookie_string.split(';').map { |s| s.strip }
  data_cookie = cookies.find { |c| c =~ /\Aexperimoto_data=/ }
  cookie_hash = {}
  if data_cookie
    data_cookie = /\A[^=]+=(.*)\z/.match(data_cookie)[1]
    cookie_hash = {'experimoto_data' => data_cookie}
    user = Experimoto::User.new(:cookie_hash => cookie_hash, :hmac_key => hmac_key, :ignore_hmac => true)
  else
    user = Experimoto::User.new()
  end
  if opts[:id_string]
    user.id = URI.escape(opts[:id_string])
  end
  if opts[:groups_string]
    opts[:groups_string].split(':').map { |s| s.split('=') }.each do |experiment_name, group_name|
      user.groups[experiment_name] = group_name
    end
  end
  user.is_tester = opts[:is_tester]
  cookie_hash = user.to_cookie(hmac_key)
  ";;;;;;;;;; " + cookie_hash.map { |k,v| "document.cookie = '#{k}=#{v}'" }.join('; ') + " ;;;;;;;;;;"
end


if __FILE__ == $0
  options = {:is_tester => true}
  optparse = OptionParser.new do|opts|
    opts.banner = "Usage: cookie.rb [options]"
    
    opts.on('-c', '--cookie COOKIE', 'whatever comes out of the console if you write document.cookie;'
            ) do |cookie|
      options[:original_cookie_string] = cookie
    end
    
    opts.on('-g', '--groups GROUPS', 'define what experiment-groups you want the cookie to have. Example: --groups testname=testgroup:othertest=othergroup') do |groups|
      options[:groups_string] = groups
    end
    
    opts.on('-i', '--id ID', 'define what id you want the cookie to have.') do |id|
      options[:id_string] = id
    end
    
    opts.on('-t', '--test BOOLEAN', 'should this be marked as a tester user? "true" or "false" (defaulting to "true")') do |is_tester|
      options[:is_tester] = is_tester == 'true'
    end
    
    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
  end
  
  optparse.parse!
  
  puts reshape_cookies(options)
end
