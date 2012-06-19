class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name
      t.text :foobar
      t.integer :sub_cost
      t.string :sub_type
      t.timestamps
    end
  end
end
