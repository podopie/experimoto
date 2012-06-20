
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

class TestMultivariateExperiments < Test::Unit::TestCase
  
  def test_abab
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x = e.add_new_experiment(:name => 'test_experiment', :type => 'UCB1Experiment',
                             :multivariate => true,
                             :experiments => { 'test_0' => ['a','b'],
                               'test_1' => ['c','d'],
                               'test_2' => ['e','f'],
                             })
    
    old_seed = srand(123)
    
    u = e.user_from_cookie({})

    e.user_experiment(u, 'test_0')
    group = u.groups['test_experiment']
    assert_equal(1, u.groups.size)
    
    e.track(u, 'success', 1)
    
    assert_equal(1.0, x.utility(group))
    
    300.times do
      u = e.user_from_cookie({})
      g0 = e.user_experiment(u, 'test_0')
      e.track(u, 'success', 1) if rand() < (g0 == 'a' ? 0.1 : 0.4)
    end
    
    groups = x.plays.keys.sort
    4.times do |i|
      assert(x.plays[groups[i]] < x.plays[groups[i+4]])
    end
    e.db_sync
    groups = x.plays.keys.sort
    4.times do |i|
      assert(x.plays[groups[i]] < x.plays[groups[i+4]])
    end
  ensure
    begin
      srand(old_seed)
    rescue
    end
  end
  
end
