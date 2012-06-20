
require File.expand_path(File.join(File.dirname(__FILE__),'..','test','test_helper.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','experimoto-rails.rb'))

class TestRailsInterface < Test::Unit::TestCase
  
  def test_cookie_passing
    initialize_experimoto(:db => ":memory:")
    $experimoto.add_new_experiment(:name => 'test', :type => 'ABExperiment',
                                   :groups => ['asdf'], :utility_function => 'testkey')
    cookies = {}
    assert_equal('asdf', $experimoto.rails_sample(cookies, 'test'))
    assert(cookies.include?('experimoto_mac'))
    assert(cookies.include?('experimoto_data'))
    m1 = cookies['experimoto_mac']
    d1 = cookies['experimoto_data']
    assert_equal('asdf', $experimoto.rails_sample(cookies, 'test'))
    assert(cookies.include?('experimoto_mac'))
    assert(cookies.include?('experimoto_data'))
    m2 = cookies['experimoto_mac']
    d2 = cookies['experimoto_data']
    assert_equal(m1, m2)
    assert_equal(d1, d2)
    
    assert_equal('blah', $experimoto.rails_sample(cookies, 'nonexistent', :default => 'blah'))
    assert_equal('asdf', $experimoto.rails_sample(cookies, 'test', :default => 'blah'))
    
    $experimoto.rails_track(cookies, 'testkey', 5)
    assert_equal(5, $experimoto.experiments['test'].event_totals['asdf']['testkey'])
    $experimoto.rails_track(cookies, 'testkey')
    $experimoto.db_sync
    assert_equal(6, $experimoto.experiments['test'].event_totals['asdf']['testkey'])
    
    @cookies = cookies
    def self.cookies
      @cookies
    end
    
    assert_equal('asdf', experiment!('test'))
    assert_equal('blah', experiment!('nonexistent', :default => 'blah'))
    assert_equal('asdf', experiment!('test', :default => 'blah'))
    
    datum!('testkey', 3)
    assert_equal(9, $experimoto.experiments['test'].event_totals['asdf']['testkey'])
    datum!('testkey')
    $experimoto.db_sync
    assert_equal(10, $experimoto.experiments['test'].event_totals['asdf']['testkey'])
    
  end
  
end
