
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

class TestDBABExperiment < Test::Unit::TestCase
  
  def test_ab_default_sample
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    e.add_new_experiment(:type => 'ABExperiment', :name => 'test')
    assert_equal('default', e.user_experiment(e.new_user_into_db, 'test'))
  end
  
  def test_ab_triple_sample
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    e.add_new_experiment(:type => 'ABExperiment', :name => 'test', :groups => ['0','1','2'])
    counts = [0,0,0]
    
    num_samples = 100
    num_samples.times do
      sample = e.user_experiment(e.new_user_into_db, 'test')
      counts[sample.to_i] += 1
    end
    assert_not_equal(counts.min, 0)
    assert_not_equal(counts.max, num_samples)
    assert(num_samples/5 > counts.max - counts.min)
  end
  
  def test_weights
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x = e.add_new_experiment(:type => 'ABExperiment', :name => 'test', :groups => ['0','1','2'],
                             :group_split_weights => {'1' => 2.0, '2' => 3.0})
    assert_equal(1.0, x.group_split_weights['0'])
    assert_equal(2.0, x.group_split_weights['1'])
    assert_equal(3.0, x.group_split_weights['2'])
    counts = [0,0,0]
    
    num_samples = 300
    num_samples.times do
      sample = e.user_experiment(e.new_user_into_db, 'test')
      counts[sample.to_i] += 1
    end
    assert_not_equal(counts.min, 0)
    assert_not_equal(counts.max, num_samples)
    assert(counts[1] > counts[0])
    assert(num_samples/10.0 > (counts[1]/2.0 - counts[0]).abs)
    assert(counts[2] > counts[1])
    assert(num_samples/10.0 > (counts[1]/2.0 - counts[2]/3.0).abs)
    assert(counts[1] > counts[0])
    assert(num_samples/10.0 > (counts[2]/3.0 - counts[0]).abs)
  end
 
end
