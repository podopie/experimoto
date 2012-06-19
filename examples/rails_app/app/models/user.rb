class User < ActiveRecord::Base
  attr_accessible :name, :foobar, :sub_cost, :sub_type
end
