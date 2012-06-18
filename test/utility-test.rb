
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))

class TestUtilityFunctions < Test::Unit::TestCase
  def test_utility_functions
    dbh = RDBI.connect(:SQLite3, :database => ":memory:")
    e = Experimoto::Experimoto.new(:dbh => dbh)
    e.db_sync
    
    x = e.add_new_experiment(:type => 'UCB1Experiment', :name => 'test-experiment',
                             :groups => ['0','1','2','3','4'],
                             :utility_function => '(payment/1000)+sign_up')
    
    choices = [0,0,0,0,0]
    100.times do |ix|
      u = e.new_user_into_db
      sample = e.user_experiment(u, 'test-experiment')
      e.track(u, 'sign_up') if sample.to_i < 4
      e.track(u, 'payment', 500) if sample.to_i < 3
      e.track(u, 'payment', 300) if sample.to_i < 2
      e.track(u, 'payment', 100) if sample.to_i < 1
      choices[sample.to_i] += 1
      e.db_sync if 0 == ix % 17
    end
    
    4.times do |i|
      assert(choices[i] > choices[i+1])
    end
    
  end
end
