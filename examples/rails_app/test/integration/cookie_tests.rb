require 'test_helper'

class CookieTests < ActionDispatch::IntegrationTest
  
  def test_user_gets_cookie
    get '/users/new'
    assert_equal(nil, cookies['jkasldjfkljdskfld'])
    assert_not_equal(nil, cookies['experimoto_mac'])
    assert_not_equal(nil, cookies['experimoto_data'])
    uid = /id.*([A-z0-9\-_]{22})/.match(cookies['experimoto_data'])[1]
    assert_not_equal(nil, uid)
    assert_equal(22, uid.size)
  end
  
  def test_user_gets_tracked
    get '/users/new'
    uid1 = /id.*([A-z0-9\-_]{22})/.match(cookies['experimoto_data'])[1]
    
    get '/users'
    get '/users/new'
    uid2 = /id.*([A-z0-9\-_]{22})/.match(cookies['experimoto_data'])[1]
    assert_equal(uid1, uid2)
  end
  
end
