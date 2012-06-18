
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

class TestDB < Test::Unit::TestCase
  
  def test_experiment_acquisition
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    
    x = Experimoto::Experimoto.new(:dbh => dbh)
    x.db_sync
    
    assert_equal(0, x.experiments.size)
    
    e = Experimoto::UCB1Experiment.new(:name => 'test-experiment')
    e_row = e.to_row
    dbh.prepare('insert into experiments values (?,?,?,?,?,?);') do |sth|
      sth.execute(*e_row)
    end
    db_e_row = nil
    dbh.execute('select * from experiments;').to_a.each do |row|
      next if row.nil?
      db_e_row = row
    end
    assert_equal(e_row, db_e_row)
    
    x.db_sync
    
    assert_equal(1, x.experiments.size)
  end
  
  def test_user_creation
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    x = Experimoto::Experimoto.new(:dbh => dbh)
    x.db_sync
    
    assert_equal(0, x.experiments.size)
    x.new_user_into_db
    
    db_row = nil
    dbh.execute('select count(*) from users;').to_a.each do |row|
      next if row.nil?
      db_row = row
    end
    assert_equal([1], db_row)
  end
  
  def test_replace_experiment_ab_ucb1
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x1 = e.add_new_experiment(:type => 'ABExperiment', :name => 'test-experiment',
                              :groups => ['a','b'], :group_split_weights => {'a' => 4})
    x2 = e.replace_experiment(x1.to_hash.merge(:type => 'UCB1Experiment'))
    assert_equal('UCB1Experiment', x2.type)
    assert_equal(x1.data, x2.data)
    assert_equal(x1.name, x2.name)
  end
  
  def test_replace_experiment_groups
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x1 = e.add_new_experiment(:type => 'ABExperiment', :name => 'test-experiment',
                              :groups => ['a','b'], :group_split_weights => {'a' => 4})
    x2 = e.replace_experiment(x1.to_hash.merge(:groups => ['a','b','c']))
    assert_equal(x1.name, x2.name)
    assert(x2.groups.include?('a'))
    assert(x2.groups.include?('b'))
    assert(x2.groups.include?('c'))
  end
  
  def test_replace_experiment_ab_ucb1_multivariate
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x1 = e.add_new_experiment(:type => 'ABExperiment', :name => 'test-experiment',
                              :multivariate => true,
                              :experiments => {'a' => ['1','2','3'], 'b' => ['4','5','6']})
    x2 = e.replace_experiment(x1.to_hash.merge(:type => 'UCB1Experiment'))
    assert_equal('UCB1Experiment', x2.type)
    assert_equal(x1.name, x2.name)
    assert(x1.groups, x2.groups)
  end
  
  def test_user_experiment
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    x = Experimoto::Experimoto.new(:dbh => dbh)
    x.db_sync
    assert_equal(0, x.experiments.size)
    e = Experimoto::UCB1Experiment.new(:name => 'test-experiment')
    e_row = e.to_row
    dbh.prepare('insert into experiments values (?,?,?,?,?,?);') do |sth|
      sth.execute(*e_row)
    end
    db_e_row = nil
    dbh.execute('select * from experiments;').to_a.each do |row|
      next if row.nil?
      db_e_row = row
    end
    assert_equal(e_row, db_e_row)
    x.db_sync
    assert_equal(1, x.experiments.size)
    
    
    u = x.new_user_into_db
    
    db_row = nil
    dbh.execute('select count(*) from users;').to_a.each do |row|
      next if row.nil?
      db_row = row
    end
    assert_equal([1], db_row)
    
    x.user_experiment(u, 'test-experiment')
    
    db_row = nil
    dbh.execute('select count(*) from groupings;').to_a.each do |row|
      next if row.nil?
      db_row = row
    end
    assert_equal([1], db_row)
    
    x.db_sync
    
    assert_equal(1, x.experiments['test-experiment'].plays['default'])
    
    u2 = x.new_user_into_db
    
    db_row = nil
    dbh.execute('select count(*) from users;').to_a.each do |row|
      next if row.nil?
      db_row = row
    end
    assert_equal([2], db_row)
    
    x.user_experiment(u2, 'test-experiment')
    
    db_row = nil
    dbh.execute('select count(*) from groupings;').to_a.each do |row|
      next if row.nil?
      db_row = row
    end
    assert_equal([2], db_row)
    
    x.db_sync
    
    assert_equal(2, x.experiments['test-experiment'].plays['default'])
    
    x.user_experiment_event(u2, 'test-experiment', 'success', 1)
    
    x.db_sync
    assert_equal(0.5, x.experiments['test-experiment'].utility('default'))
    
  end

 
end
