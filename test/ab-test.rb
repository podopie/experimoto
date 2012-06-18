

require 'test/unit'
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','ab-experiment'))

class TestABExperiment < Test::Unit::TestCase
  
  def test_ab_default_sample
    x = Experimoto::ABExperiment.new(:name => 'test')
    assert_equal(x.sample, 'default')
  end
  
  def test_ab_triple_sample
    x = Experimoto::ABExperiment.new(:name => 'test')
    x.groups.delete('default')
    num_groups = 3
    num_groups.times do |i|
      name = i.to_s
      x.groups[name] = Experimoto::ExperimentGroup.new(:name => name)
    end
    counts = num_groups.times.map { 0 }
    
    num_samples = 1000
    num_samples.times do
      counts[x.sample.to_i] += 1
    end
    assert_not_equal(counts.min, 0)
    assert_not_equal(counts.max, num_samples)
    assert(num_samples/10 > counts.max - counts.min)
  end
 
end
