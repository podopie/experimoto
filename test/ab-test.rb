
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

class TestABExperiment < Test::Unit::TestCase
  
  def test_ab_default_sample
    x = Experimoto::ABExperiment.new(:name => 'test')
    assert_equal(x.sample, 'default')
  end
  
  def test_ab_triple_sample
    x = Experimoto::ABExperiment.new(:name => 'test', :groups => ['0','1','2'])
    counts = [0,0,0]
    
    num_samples = 1000
    num_samples.times do
      counts[x.sample.to_i] += 1
    end
    assert_not_equal(counts.min, 0)
    assert_not_equal(counts.max, num_samples)
    assert(num_samples/10 > counts.max - counts.min)
  end
  
  def test_weights
    x = Experimoto::ABExperiment.new(:name => 'test', :groups => ['0','1','2'],
                                     :group_split_weights => {'1' => 2.0, '2' => 3.0})
    assert_equal(1.0, x.group_split_weights['0'])
    assert_equal(2.0, x.group_split_weights['1'])
    assert_equal(3.0, x.group_split_weights['2'])
    counts = [0,0,0]
    
    num_samples = 1000
    num_samples.times do
      counts[x.sample.to_i] += 1
    end
    assert_not_equal(counts.min, 0)
    assert_not_equal(counts.max, num_samples)
    assert(counts[1] > counts[0])
    assert(num_samples/10 > (counts[1]/2.0 - counts[0]).abs)
    assert(counts[2] > counts[1])
    assert(num_samples/10 > (counts[1]/2.0 - counts[2]/3.0).abs)
  end
 
end
