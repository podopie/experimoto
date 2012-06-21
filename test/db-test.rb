
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

class TestDB < Test::Unit::TestCase
  
  def test_invalid_experiment_creation
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    assert_raise ArgumentError do
      e.experiment_type_to_class('asdf')
    end
    assert_raise ArgumentError do
      e.add_new_experiment(:type => 'fdjkl', :name => 'test')
    end
    assert_raise ArgumentError do
      e.add_new_experiment(:type => 'ABExperiment', :name => 'test', :multivariate => true)
    end
    assert_raise ArgumentError do
      e.add_new_experiment(:type => 'ABExperiment', :name => 'test',
                           :multivariate => true, :experiments => ['asdf', 'blah'])
    end
    assert_raise ArgumentError do
      e.add_new_experiment(:type => 'ABExperiment', :name => 'blah-blah')
    end
    assert_raise ArgumentError do
      x = e.add_new_experiment(:type => 'ABExperiment', :name => 'blah_blah', :groups => 'asdf')
      puts x.inspect
    end
  end
  
  def test_experiment_group_annotations
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment',
                         :groups => ['test_group'],
                         :group_annotations => {'test_group' => 'test_annotation'})
    u = e.new_user_into_db
    assert_equal('test_annotation',
                 e.user_experiment(u, 'test_experiment', :return_annotation => true))
  end
  
  def test_experiment_group_annotation_fallback
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment',
                         :groups => ['test_group'],
                         :group_annotations => {})
    u = e.new_user_into_db
    assert_equal('test_group',
                 e.user_experiment(u, 'test_experiment', :return_annotation => true))
  end
  
  def test_invalid_experiment_saving
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    assert_raise ArgumentError do
      e.save_experiment(:name => 7)
    end
  end
  
  def test_experiment_deletion
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment')
    e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment2')
    assert(e.experiments.include?('test_experiment'))
    assert(e.experiments.include?('test_experiment2'))
    e.delete_experiment('test_experiment')
    assert(!e.experiments.include?('test_experiment'))
    assert(e.experiments.include?('test_experiment2'))
  end
  
  def test_experiment_view_deletion_cascade
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment', :multivariate => true,
                         :experiments => {'test1' => ['1','2','3'], 'test2' => ['1','2','3'] })
    e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment2', :multivariate => true,
                         :experiments => {'test12' => ['1','2','3'], 'test22' => ['1','2','3'] })
    assert(e.experiments.include?('test_experiment'))
    assert(e.experiments.include?('test1'))
    assert(e.experiments.include?('test2'))
    assert(e.experiments.include?('test_experiment2'))
    assert(e.experiments.include?('test12'))
    assert(e.experiments.include?('test22'))
    e.delete_experiment('test_experiment')
    assert(!e.experiments.include?('test_experiment'))
    assert(!e.experiments.include?('test1'))
    assert(!e.experiments.include?('test2'))
    assert(e.experiments.include?('test_experiment2'))
    assert(e.experiments.include?('test12'))
    assert(e.experiments.include?('test22'))
  end
  
  def test_experiment_acquisition
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    
    x = Experimoto::Experimoto.new(:dbh => dbh)
    x.db_sync
    
    assert_equal(0, x.experiments.size)
    
    e = Experimoto::UCB1Experiment.new(:name => 'test_experiment')
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
  
  def test_experiment_name_uniqueness
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment')
    assert_raise SQLite3::ConstraintException do
      e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment')
    end
    x = e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment2')
    assert_raise RuntimeError, SQLite3::ConstraintException do
      e.replace_experiment(:id => x.id, :type => 'ABExperiment', :name => 'test_experiment')
    end
  end
  
  def test_replace_experiment_description
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x1 = e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment',
                              :description => 'foo')
    assert_equal('foo', x1.description)
    x2 = e.replace_experiment(x1.to_hash.merge(:description => 'bar'))
    assert_equal('bar', x2.description)
    assert_equal(x1.data, x2.data)
    assert_equal(x1.name, x2.name)
  end
  
  def test_replace_experiment_ab_ucb1
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    x1 = e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment',
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
    x1 = e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment',
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
    x1 = e.add_new_experiment(:type => 'ABExperiment', :name => 'test_experiment',
                              :multivariate => true,
                              :experiments => {'a' => ['1','2','3'], 'b' => ['4','5','6']})
    x2 = e.replace_experiment(x1.to_hash.merge(:type => 'UCB1Experiment'))
    assert_equal('UCB1Experiment', x2.type)
    assert_equal(x1.name, x2.name)
    assert_equal(x1.groups, x2.groups)
  end
  
  def test_user_experiment
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    x = Experimoto::Experimoto.new(:dbh => dbh)
    x.db_sync
    assert_equal(0, x.experiments.size)
    e = Experimoto::UCB1Experiment.new(:name => 'test_experiment')
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
    
    x.user_experiment(u, 'test_experiment')
    
    db_row = nil
    dbh.execute('select count(*) from groupings;').to_a.each do |row|
      next if row.nil?
      db_row = row
    end
    assert_equal([1], db_row)
    
    x.db_sync
    
    assert_equal(1, x.experiments['test_experiment'].plays['default'])
    
    u2 = x.new_user_into_db
    
    db_row = nil
    dbh.execute('select count(*) from users;').to_a.each do |row|
      next if row.nil?
      db_row = row
    end
    assert_equal([2], db_row)
    
    x.user_experiment(u2, 'test_experiment')
    
    db_row = nil
    dbh.execute('select count(*) from groupings;').to_a.each do |row|
      next if row.nil?
      db_row = row
    end
    assert_equal([2], db_row)
    
    x.db_sync
    
    assert_equal(2, x.experiments['test_experiment'].plays['default'])
    
    x.user_experiment_event(u2, 'test_experiment', 'success', 1)
    
    x.db_sync
    assert_equal(0.5, x.experiments['test_experiment'].utility('default'))
    
    u = x.new_user_into_db
    orig_date = u.modified_at
    sleep 2
    
    x.user_experiment(u, 'test_experiment')
    new_date = u.modified_at
    assert(new_date > orig_date)
    dbh.prepare('select modified_at from users where id = ?;') do |sth|
      sth.execute(u.id).each do |o|
        next if o.nil?
        assert(o[0] > orig_date)
      end
    end

  end

 
end
