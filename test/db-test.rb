
require 'test/unit'
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

require 'rubygems'

require 'thread'
require 'rdbi'
require 'rdbi-driver-sqlite3'

require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','experimoto'))

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
