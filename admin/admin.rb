
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','experimoto'))
require 'rdbi-driver-sqlite3'

db_location = File.expand_path(File.join(File.dirname(__FILE__),'..','test-db.sqlite3'))
dbh = RDBI.connect(:SQLite3, :database => db_location)
$experimoto = Experimoto::Experimoto.new(:dbh => dbh)
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
  erb :index
end

get '/new/univariate' do
  erb :create_univariate, :locals => {:experiment => nil}
end

post '/new/univariate' do
  x = $experimoto.add_new_experiment(params_to_experiment_hash(params))
  redirect '/'
end

get '/new/multivariate' do
  erb :create_multivariate
end

post '/new/multivariate' do
  sub_experiments = {}
  1000.times do |i|
    break unless params["experiment_name_#{i}"]
    gl = []
    1000.times do |j|
      break unless params["group_name_#{i}_#{j}"]
      gl << params["group_name_#{i}_#{j}"]
    end
    sub_experiments[params["experiment_name_#{i}"]] = gl
  end
  h = params_to_experiment_hash(params)
  h.delete(:groups)
  h.delete(:group_split_weights)
  h.merge!(:experiments => sub_experiments, :multivariate => true)
  x = $experimoto.add_new_experiment(h)
  redirect "/experiment/#{x.id}"
end

get '/experiment/:id/edit' do
  @experiment = $experimoto.experiments.values.find { |x| x.id == params[:id] }
  erb :edit_univariate #, :locals => {:experiment => experiment}
end

post '/experiment/:id/edit' do
  x = $experimoto.replace_experiment(params_to_experiment_hash(params).merge(:id => params[:experiment_id]))
  redirect "/experiment/#{params[:experiment_id]}"
end

get '/experiment/:id' do
  $experimoto.db_sync
  experiment = $experimoto.experiments.values.find { |x| x.id == params[:id] }
  if experiment.total_plays > 0 # 100
    #let's make a graph!
    @has_chart_info = true
    sample_count = 10
    @chart_sample_count = sample_count
    t0 = DateTime.parse(experiment.created_at) if experiment.created_at
    t0 ||= DateTime.now - 10
    t1 = nil
    $experimoto.dbh.prepare('select max(created_at) from events where eid = ?') do |sth|
      sth.execute(experiment.id).each do |row|
        next if row.nil? || row[0].nil?
        t1 = DateTime.parse(row[0])
        break
      end
    end
    t1 ||= DateTime.now
    starts = sample_count.times.to_a.map { |i| t0 + (t1-t0)*i*1.0/sample_count }
    ends = sample_count.times.to_a.map { |i| t0 + (t1-t0)*(i+1)*1.0/sample_count }
    @date_row = starts.map { |d| d.to_s }
    sample_count.times do |i|
      utilities = {}
      plays = {}
      experiment.sync_play_data($experimoto.dbh, :plays => plays,
                                :start_date => starts[i], :end_date => ends[i])
      experiment.groups.keys.each do |group_name|
        utilities[group_name] = experiment.utility(group_name, :dbh => $experimoto.dbh,
                                                   :start_date => starts[i], :end_date => ends[i])
        @utilities_rows ||= {}
        @utilities_rows[group_name] ||= []
        @utilities_rows[group_name] << utilities[group_name]
        @plays_rows ||= {}
        @plays_rows[group_name] ||= []
        @plays_rows[group_name] << plays[group_name]
      end
      if experiment.type =~ /ucb1/i
        experiment.groups.keys.each do |group_name|
          @confidences_rows ||= {}
          @confidences_rows[group_name] ||= []
          cp = {}
          @plays_rows.each do |k,v|
            cp[k] ||= 0
            v.each do |n|
              cp[k] += n
            end
          end
          @confidences_rows[group_name] << experiment.confidence_bound(group_name, experiment.utilities.values.max, cp)
        end
      end
    end
  end
  erb :experiment, :locals => {:experiment => experiment}
end

post '/experiment/:id' do
  key = params[key]
  value = params[value]
  $experimoto.push_data(:data => [key, value])
end

get '/experiment/:id/delete' do
  @experiment = $experimoto.experiments.values.find { |x| x.id == params[:id] }
  erb :delete
end
post '/experiment/:id/delete' do
  x = $experimoto.experiments.values.find { |x| x.id == params[:id] }
  $experimoto.delete_experiment(x.name)
  redirect '/'
end


def params_to_experiment_hash(params)
  experiment_name = params[:experiment_name]
  type = params[:type]
  description =  params[:description]
  groups = []
  weights = {}
  group_annotations = {}
  1000.times do |i|
    break unless params["group_name_#{i}"]
    name = params["group_name_#{i}"]
    groups << name
    weight = nil
    begin
      weight = params["group_weight_#{i}"].to_f if params["group_weight_#{i}"].size > 0
    rescue
    end
    weights[name] = weight if weight && weight >= 0.0
    annotation = params["group_annotation_#{i}"]
    group_annotations[name] = annotation if annotation && annotation.size > 0
  end
  uf = params[:utility_function]
  uf = nil if uf.nil? || uf.size < 1
  {:name => experiment_name, :type => type, :description => description,
    :groups => groups, :group_split_weights => weights,
    :utility_function => uf, :group_annotations => group_annotations}
end

get '/user/' do
  # TODO: someday, have it be /user/:user_id, and have it list groups, and
  # stats, etc. for now though, just a form for applying a group to a
  # user.
  erb :user
end
#post '/user/:id/set_group/:experiment_name/:group_name' do
post '/user/' do
  # NOTE: this basically just changes what will happen to the user's
  # cookie in the future. a better thing to do would be to delete any
  # groupings from the past, and also change any existing events.
  uid = params[:user_id]
  raise ArgumentError unless uid.size == 22
  experiment = $experimoto.experiments[params[:experiment_name]]
  $experimoto.user_db_grouping!(uid, experiment.id, params[:group_name])
  redirect "/user/"
end

