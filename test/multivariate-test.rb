
require 'test/unit'
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

require 'rubygems'

require 'thread'
require 'rdbi'
require 'rdbi-driver-sqlite3'

require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','experimoto'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','experiment'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','experiment-view'))

class TestMultivariateExperiments < Test::Unit::TestCase
  
  def test_abab
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x = e.add_new_experiment(:name => 'test-experiment', :type => 'UCB1Experiment',
                             :multivariate => true,
                             :experiments => { 'test-0' => ['a','b'],
                               'test-1' => ['c','d'],
                               'test-2' => ['e','f'],
                             })
    
    old_seed = srand(123)
    
    u = e.user_from_cookie({})

    e.user_experiment(u, 'test-0')
    group = u.groups['test-experiment']
    assert_equal(1, u.groups.size)
    
    e.track(u, 'success', 1)
    
    assert_equal(1.0, x.utility(group))
    
    1000.times do
      u = e.user_from_cookie({})
      g0 = e.user_experiment(u, 'test-0')
      e.track(u, 'success', 1) if rand() < (g0 == 'a' ? 0.1 : 0.4)
    end
    
    case RUBY_VERSION[0..2]
    when '1.8'
      groups = x.plays.keys.sort
      4.times do |i|
        assert(x.plays[groups[i]] < x.plays[groups[i+4]])
      end
      e.db_sync
      groups = x.plays.keys.sort
      4.times do |i|
        assert(x.plays[groups[i]] < x.plays[groups[i+4]])
      end
    when '1.9'
      expected_plays = {
        '["a","c","e"]' =>  42,
        '["a","c","f"]' =>  45,
        '["a","d","e"]' =>  63,
        '["a","d","f"]' =>  48,
        '["b","c","e"]' => 215,
        '["b","c","f"]' => 229,
        '["b","d","e"]' => 185,
        '["b","d","f"]' => 174 }
      assert_equal(expected_plays, x.plays)
      e.db_sync
      assert_equal(expected_plays, x.plays)
    end
    
  ensure
    begin
      srand(old_seed)
    rescue
    end
  end
  
end
