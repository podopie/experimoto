
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

class TestDB < Test::Unit::TestCase
  
  def init_steps
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x = e.add_new_experiment(:name => 'test_experiment', :type => 'ABExperiment', :groups => ['a','b'])
    [dbh, e, x]
  end
  
  def test_stats_initially_zero
    h, e, x = init_steps
    assert_equal(0, Experimoto::EventStats.get_event_stat(h, x.id, 'a', 'some_key', 'value_sum'))
  end
  
  def test_stats_set_once
    h, e, x = init_steps
    Experimoto::EventStats.add_event_stat(h, x.id, 'a', 'some_key', 'value_sum')
    assert_equal(1, Experimoto::EventStats.get_event_stat(h, x.id, 'a', 'some_key', 'value_sum'))
  end
  
  def test_stats_set_twice
    h, e, x = init_steps
    Experimoto::EventStats.add_event_stat(h, x.id, 'a', 'some_key', 'value_sum')
    Experimoto::EventStats.add_event_stat(h, x.id, 'a', 'some_key', 'value_sum')
    assert_equal(2, Experimoto::EventStats.get_event_stat(h, x.id, 'a', 'some_key', 'value_sum'))
  end
  
  def test_stats_nondefault
    h, e, x = init_steps
    v1 = rand()+13.0
    v2 = rand()+17.0
    Experimoto::EventStats.add_event_stat(h, x.id, 'a', 'some_key', 'value_sum', v1)
    assert_equal(v1, Experimoto::EventStats.get_event_stat(h, x.id, 'a', 'some_key', 'value_sum'))
    Experimoto::EventStats.add_event_stat(h, x.id, 'a', 'some_key', 'value_sum', v2)
    assert_equal(v1 + v2, Experimoto::EventStats.get_event_stat(h, x.id, 'a', 'some_key', 'value_sum'))
  end
  
  def test_user_experiment_event
    h, e, x = init_steps
    u = e.new_user_into_db
    assert_equal(0, Experimoto::EventStats.get_event_stat(h, x.id, 'a', '', 'play_count'))
    assert_equal(0, Experimoto::EventStats.get_event_stat(h, x.id, 'b', '', 'play_count'))
    group = e.user_experiment(u, x.name)
    assert_equal(1, Experimoto::EventStats.get_event_stat(h, x.id, group, '', 'play_count'))
    v1 = rand()+7.0
    v2 = rand()+23.0
    e.user_experiment_event(u, x.name, 'some_key', v1)
    assert_equal(v1, Experimoto::EventStats.get_event_stat(h, x.id, group, 'some_key', 'value_sum'))
    assert_equal(v1*v1, Experimoto::EventStats.get_event_stat(h, x.id, group, 'some_key', 'value_squared_sum'))
    e.user_experiment_event(u, x.name, 'some_key', v2)
    assert_equal(v1+v2, Experimoto::EventStats.get_event_stat(h, x.id, group, 'some_key', 'value_sum'))
    assert_equal(v1*v1+v2*v2, Experimoto::EventStats.get_event_stat(h, x.id, group, 'some_key', 'value_squared_sum'))
  end
  
end
