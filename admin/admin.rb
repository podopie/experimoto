require 'rubygems'
require 'thread'
require 'rdbi'
require 'rdbi-driver-sqlite3'
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','experimoto'))

$experimoto = Experimoto::Experimoto.new(:dbh => RDBI.connect(:SQLite3, :database => ":memory:"))
$experimoto.db_sync
$experimoto.start_syncing_thread

require 'sinatra'

get '/' do
  erb :index
end

get '/new/univariate' do
  erb :create
end

post '/new/univariate' do
  name = params[:name]
  type = params[:type]
  $experimoto.add_new_experiment(:name => name, :type => type)
  redirect '/experiment'
end

get '/new/multivariate' do
  erb :create_multivariate
end

post '/new/multivariate' do
  name = params[:name]
  type = params[:type]
  $experimoto.add_new_experiment(:name => name, :type => type)
  redirect '/experiment'
end

get '/experiment' do
  experiments = []
  $experimoto.mutex.synchronize do
    $experimoto._db_sync
    $experimoto.experiments.keys.sort.each do |k|
      experiments << $experimoto.experiments[k]
    end
  end
  erb :show, :locals => {:experiments => experiments}
end

get '/experiment_create' do
  params.each do |k,v|
    params[k.to_sym] = v
  end
  $experimoto.add_new_experiment(params)
end

get '/experiment/:id/edit' do
  erb :edit
end

get '/experiment/:id' do
  experiment = @experiments.id
  erb :experiment, :locals => {:experiment => experiment}
end

post '/experiment/:id' do
  key = params[key]
  value = params[value]
  $experimoto.push_data(:data => [key, value])
end