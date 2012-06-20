


require File.expand_path(File.join(File.dirname(__FILE__),'experimoto'))

def initialize_experimoto(opts={})
  database_handle = RDBI.connect(:SQLite3, :database => opts[:db])
  $experimoto = Experimoto::Experimoto.new(:dbh => database_handle)
  $experimoto.db_sync
  $experimoto.start_syncing_thread(:sleep_time => opts[:sync_interval])
end

Object.class_eval do
  def experiment!(experiment_name, opts = {})
    $experimoto.rails_sample(cookies, experiment_name, opts)
  end
  def datum!(key, value = 1)
    $experimoto.rails_track(cookies, key, value)
  end
end

