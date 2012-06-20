


require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','experimoto'))
require 'rdbi-driver-sqlite3'



db_location = File.expand_path(File.join(File.dirname(__FILE__),'..','test-db.sqlite3'))
dbh = RDBI.connect(*[:SQLite3, {:database => db_location}])
$experimoto = Experimoto::Experimoto.new(:dbh => dbh)
$experimoto.db_sync

x = $experimoto.delete_experiment('canned_data_experiment')
x = $experimoto.add_new_experiment(:name => 'canned_data_experiment',
                                   :type => 'UCB1Experiment',
                                   :groups => ['a', 'b', 'c'],
                                   :utility_function => 'wargle + bargle'
                                   )

wp = {'a' => 0.11, 'b' => 0.10, 'c' => 0.105 }
bp = {'a' => 0.05, 'b' => 0.10, 'c' => 0.13 }

outer_loops = 100
outer_loops.times do |i|
  puts "starting #{i} of #{outer_loops}"
  sleep 0.2
  200.times do
    u = $experimoto.new_user_into_db
    s = $experimoto.user_experiment(u, 'canned_data_experiment')
    $experimoto.track(u, 'wargle') if rand() < wp[s]
    $experimoto.track(u, 'bargle') if rand() < bp[s]
  end
  $experimoto.db_sync
end




