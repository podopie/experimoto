
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

class TestExperimentViews < Test::Unit::TestCase
  
  def test_unimplemented_methods
    x = Experimoto::ExperimentView.new(:name => 'test')
    assert_raise(NotImplementedError) { x.sample }
    assert_raise(NotImplementedError) { x.local_event }
  end
  
  def test_view_cookie
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x1 = e.add_new_experiment(:name => 'test-experiment', :type => 'ABExperiment')
    xv = e.add_new_experiment(:name => 'test-experiment-view', :type => 'ExperimentView',
                              :target_experiment_name => 'test-experiment')
    u = e.user_from_cookie({})
    assert_equal('default', e.user_experiment(u, 'test-experiment-view'))
    assert_equal(nil, u.groups['test-experiment-view'])
    assert_equal('default', u.groups['test-experiment'])
    
    c = e.user_to_cookie(u)
    c_groups = JSON.parse(URI.unescape(c['experimoto_data']))['groups']
    assert_equal(nil,       c_groups['test-experiment-view'])
    assert_equal('default', c_groups['test-experiment'])
    
    u1 = e.user_from_cookie(c)
    assert_equal('default', e.user_experiment(u1, 'test-experiment-view'))
    assert_equal(nil, u1.groups['test-experiment-view'])
    assert_equal('default', u1.groups['test-experiment'])
    
  end
  
  def test_basic_view
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x1 = e.add_new_experiment(:name => 'test-experiment', :type => 'ABExperiment')
    xv = e.add_new_experiment(:name => 'test-experiment-view', :type => 'ExperimentView',
                              :target_experiment_name => 'test-experiment')
    u = e.user_from_cookie({})
    assert_equal('default', e.user_experiment(u, 'test-experiment-view'))
    assert_equal(nil, u.groups['test-experiment-view'])
    assert_equal('default', u.groups['test-experiment'])
    
    e.user_experiment_event(u, 'test-experiment-view', 'success', 1)
    assert_equal(1.0, e.experiments['test-experiment'].utility('default'))
    e.db_sync
    assert_equal(1.0, e.experiments['test-experiment'].utility('default'))
    
    e.track(u, 'success', 1)
    assert_equal(2.0, e.experiments['test-experiment'].utility('default'))
    e.db_sync
    assert_equal(2.0, e.experiments['test-experiment'].utility('default'))
  end
  
  def test_indexed_view
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x1 = e.add_new_experiment(:name => 'test-experiment', :type => 'ABExperiment',
                              :groups => ['["a","z"]'])
    xv = e.add_new_experiment(:name => 'test-experiment-view', :type => 'ExperimentView',
                              :target_experiment_name => 'test-experiment',
                              :json_lookup_index => 1)
    u = e.user_from_cookie({})
    assert_equal('z', e.user_experiment(u, 'test-experiment-view'))
    assert_equal(nil, u.groups['test-experiment-view'])
    assert_equal('["a","z"]', u.groups['test-experiment'])
    
    e.user_experiment_event(u, 'test-experiment-view', 'success', 1)
    assert_equal(1.0, e.experiments['test-experiment'].utility('["a","z"]'))
    e.db_sync
    assert_equal(1.0, e.experiments['test-experiment'].utility('["a","z"]'))
    
    e.track(u, 'success', 1)
    assert_equal(2.0, e.experiments['test-experiment'].utility('["a","z"]'))
    e.db_sync
    assert_equal(2.0, e.experiments['test-experiment'].utility('["a","z"]'))
  end
  
end
