
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

class TestCookies < Test::Unit::TestCase
  
  def test_blank_cookie
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    u = e.user_from_cookie({})
    assert_not_equal(u.id, nil)
  end
  
  def test_bad_mac
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    u1 = Experimoto::User.new
    c = e.user_to_cookie(u1)
    c['experimoto_mac'][-1] = '='
    u2 = e.user_from_cookie(c)
    assert_not_equal(u1.id, u2.id)
  end
 
  def test_new_user
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    u1 = Experimoto::User.new
    c = e.user_to_cookie(u1)
    u2 = e.user_from_cookie(c)
    assert_equal(u1.id, u2.id)
    assert_equal(u1.groups, u2.groups)
  end
 
  def test_grouped_user
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    u1 = Experimoto::User.new(:groups => {'test1' => 'asdf'})
    e.experiments['test1'] = Experimoto::Experiment.new(:name => 'blah')
    c = e.user_to_cookie(u1)
    u2 = e.user_from_cookie(c)
    assert_equal(u1.id, u2.id)
    assert_equal(u1.groups, u2.groups)
    assert_equal(u1.groups['test1'], 'asdf')
    assert_equal(u1.groups.size, 1)
  end
 
  def test_deprecated_experiment
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    u1 = Experimoto::User.new(:groups => {'test1' => 'asdf'})
    c = e.user_to_cookie(u1)
    u2 = e.user_from_cookie(c)
    assert_equal(u1.id, u2.id)
    assert_not_equal(u1.groups, u2.groups)
    assert_equal(u1.groups['test1'], 'asdf')
    assert_equal(u1.groups.size, 1)
    assert_equal(u2.groups['test1'], nil)
    assert_equal(u2.groups.size, 0)
  end
 
  def test_tester
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x = e.add_new_experiment(:type => 'ABExperiment', :name => 'test-experiment')
    u1 = e.new_user_into_db(:is_tester => true)
    assert(u1.tester?)
    c = e.user_to_cookie(u1)
    u2 = e.user_from_cookie(c)
    assert(u2.tester?)
    group = e.user_experiment(u2, 'test-experiment')
    assert_not_equal(nil, group)
    assert_equal(u2.groups['test-experiment'], group)
    assert_equal(0, x.plays[group])
    e.track(u2, 'success')
    assert_equal(0, x.utility(group))
    e.db_sync
    x = e.experiments['test-experiment']
    assert_equal(0, x.plays[group])
    assert_equal(0, x.utility(group))
  end
 
end



