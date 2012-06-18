

require 'test/unit'
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','ucb1-experiment'))

class TestUCB1Experiment < Test::Unit::TestCase
  
  def test_ucb1_default_sample
    x = Experimoto::UCB1Experiment.new(:name => 'test')
    assert_equal(x.sample, 'default')
  end
  
  def test_ucb1_triple_sample
    num_groups = 3
    x = Experimoto::UCB1Experiment.new(:name => 'test',
                                       :groups => num_groups.times.to_a.map { |x| x.to_s })
    counts = num_groups.times.map { 0 }
    
    old_seed = srand(123)
    
    num_samples = 1000
    num_samples.times do
      sample = x.sample
      counts[sample.to_i] += 1
      if rand() < (sample.to_i + 1.0)/(30.0)
        x.local_event(:group_name => sample, :key => 'success', :value => 1)
      end
    end
    
    assert([214, 357, 429] == counts || [228, 309, 463] == counts,
           "incorrect counts: #{counts.inspect}")
    
    # adding a new, superior group
    counts << 0
    name = (num_groups).to_s
    x.add_group(:name => name)
    num_samples.times do
      sample = x.sample
      counts[sample.to_i] += 1
      if rand() < (sample.to_i + 1.0)/(30.0)
        x.local_event(:group_name => sample, :key => 'success', :value => 1)
      end
    end
    
    assert([244, 344, 473, 939] == counts || [229, 378, 459, 934] == counts,
           "incorrect counts: #{counts.inspect}")
  ensure
    srand(old_seed)
  end
 
end
