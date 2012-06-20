
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

class TestDBAndUCB1Experiment < Test::Unit::TestCase
  
  def test_ucb1_triple_sample
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    x = Experimoto::Experimoto.new(:dbh => dbh)
    x.db_sync
    num_groups = 3
    counts = num_groups.times.map { 0 }
    successes = num_groups.times.map { 0 }
    
    e = x.add_new_experiment(:type => 'UCB1Experiment', :name => 'test_experiment',
                             :groups => num_groups.times.to_a.map { |i| i.to_s })
    
    old_seed = srand(123)
    
    num_samples = 1000
    num_samples.times do |ix|
      u = x.new_user_into_db
      sample = x.user_experiment(u, 'test_experiment')
      counts[sample.to_i] += 1
      if rand() < (sample.to_i + 1.0)/(30.0)
        if 0 == ix % 2
          x.user_experiment_event(u, 'test_experiment', 'success', 1)
        else
          x.track(u, 'success')
        end
        successes[sample.to_i] += 1
      end
      x.db_sync if 0 == ix % 17
      counts.size.times do |i|
        if 0 == counts[i]
          expected_utility = 0
        else
          expected_utility = (1.0*successes[i])/counts[i]
        end
        assert((expected_utility -
                x.experiments['test_experiment'].utility(i.to_s)).abs < 0.01)
      end
    end
    
    assert(counts[0] < counts[1])
    assert(counts[1] < counts[2])
  ensure
    begin
      srand(old_seed)
    rescue
    end
  end
 
end
