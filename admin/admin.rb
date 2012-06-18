
require 'rubygems'

require 'thread'

require 'rdbi'
require 'rdbi-driver-sqlite3'

require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','experimoto'))

$experimoto = Experimoto::Experimoto.new(:dbh => RDBI.connect(:SQLite3, :database => ":memory:"))
$experimoto.db_sync
$experimoto.start_syncing_thread

require 'sinatra'

get '/hi' do
  'Hello World!'
end

get '/experiment_list' do
  ("<html><head></head><body>" +
   $experimoto.experiments.keys.sort.join('<br />') +
   "</body></html>"
   )
end

get '/experiment_create' do
  params.each do |k,v|
    params[k.to_sym] = v
  end
  $experimoto.add_new_experiment(params)
end

