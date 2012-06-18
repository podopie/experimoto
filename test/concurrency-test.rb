
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

class TestMultivariateExperiments < Test::Unit::TestCase
  
  def test_concurrent_sync
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e1 = Experimoto::Experimoto.new(:dbh => dbh)
    e2 = Experimoto::Experimoto.new(:dbh => dbh)
    e1.db_sync
    e2.db_sync
    
    e1.add_new_experiment(:type => 'ABExperiment', :name => 'test-experiment')
    e2.db_sync
    assert(e2.experiments.include?('test-experiment'))
    
    e2.experiments['test-experiment'].add_group(:name => 'another_group')
    e2.save_experiment('test-experiment')
    e1.db_sync
    assert(e1.experiments['test-experiment'].groups.include?('another_group'))
    
    e1.start_syncing_thread(:sleep_time => 0.1)
    e2.start_syncing_thread(:sleep_time => 0.1)
    sleep 0.2
    assert(e1.syncing_thread.thread.alive?)
      
    e2.experiments['test-experiment'].add_group(:name => 'yet_another_group')
    e2.save_experiment('test-experiment')
    runs0 = e1.syncing_thread.runs
    waits = 0
    until e1.syncing_thread.runs > runs0 || waits > 100
      sleep 0.01
      waits += 0
    end
    assert(e1.experiments['test-experiment'].groups.include?('yet_another_group'))
    
    e1.stop_syncing_thread
    e2.stop_syncing_thread
    sleep 0.2
    assert(!e1.syncing_thread.thread.alive?)
    assert(!e2.syncing_thread.thread.alive?)
  end
  
end