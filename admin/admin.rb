require 'rubygems'
require 'thread'
require 'rdbi'
require 'rdbi-driver-sqlite3'
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','experimoto'))

db_location = File.expand_path(File.join(File.dirname(__FILE__),'..','test-db.sqlite3'))
database_handle = RDBI.connect(:SQLite3, :database => db_location)
$experimoto = Experimoto::Experimoto.new(:dbh => database_handle)
$experimoto.db_sync
$experimoto.start_syncing_thread

require 'base64'
require 'openssl'
require 'sinatra'
require 'rack/csrf'

configure do
  use Rack::Session::Cookie, :secret => Base64.encode64(OpenSSL::Random.random_bytes(100))[0..-4].gsub('+','-').gsub('/','_')
  use Rack::Csrf, :raise => true
end

helpers do
  def csrf_token
    Rack::Csrf.csrf_token(env)
  end

  def csrf_tag
    Rack::Csrf.csrf_tag(env)
  end
end



get '/' do
  experiments = []
  $experimoto.mutex.synchronize do
    $experimoto._db_sync
    $experimoto.experiments.keys.sort.each do |k|
      experiments << $experimoto.experiments[k]
    end
  end
  erb :index, :locals => {:experiments => experiments}
end

get '/new/univariate' do
  erb :create_univariate, :locals => {:experiment => nil}
end

post '/new/univariate' do
  x = $experimoto.add_new_experiment(params_to_experiment_hash(params))
  puts x.inspect
  redirect '/'
end

get '/new/multivariate' do
  erb :create_multivariate
end

post '/new/multivariate' do
  name = params[:name]
  type = params[:type]
  description =  params[:description]
  $experimoto.add_new_experiment(:name => name, :type => type, :description => description)
  redirect '/experiment'
end

get '/experiment/:id/edit' do
  @experiment = $experimoto.experiments.values.find { |x| x.id == params[:id] }
  erb :edit #, :locals => {:experiment => experiment}
end

post '/experiment/:id/edit' do
  puts "params[:experiment_id] #{params[:experiment_id]}"
  x = $experimoto.replace_experiment(params_to_experiment_hash(params).merge(:id => params[:experiment_id]))
  puts x.inspect
  redirect "/experiment/#{params[:experiment_id]}"
end

get '/experiment/:id' do
  $experimoto.db_sync
  puts "id: #{params[:id]}"
  experiment = $experimoto.experiments.values.find { |x| x.id == params[:id] }
  puts "experiment: #{experiment.inspect}"
  erb :experiment, :locals => {:experiment => experiment}
end

post '/experiment/:id' do
  key = params[key]
  value = params[value]
  $experimoto.push_data(:data => [key, value])
end

def params_to_experiment_hash(params)
  experiment_name = params[:experiment_name]
  type = params[:type]
  description =  params[:description]
  groups = []
  weights = {}
  1000.times do |i|
    break unless params["group_name_#{i}"]
    name = params["group_name_#{i}"]
    groups << name
    weight = nil
    begin
      weight = params["group_weight_#{i}"].to_f
      weight = nil if weight <= 0.0
    rescue
    end
    weights[name] = weight if weight
  end
  uf = params[:utility_function]
  uf = nil if uf.nil? || uf.size < 1
  {:name => experiment_name, :type => type, :description => description,
    :groups => groups, :group_split_weights => weights,
    :utility_function => uf}
end
