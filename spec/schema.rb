ActiveRecord::Schema.define(:version => 0) do
  # Users are created and updated by other Users
  create_table :pages, :force => true do |t|
    t.column :name,           :string
    t.column :status_cd ,     :string, :limit => 2, :null => false, :default => '00'
    t.column :created_on,     :datetime
    t.column :updated_at,     :datetime
  end

  create_table :state_flow_logs, :force => true do |t|
    t.string :target_type
    t.integer :target_id
    t.string :origin_state
    t.string :origin_state_key
    t.string :dest_state
    t.string :dest_state_key
    t.string :level, :limit => 5, :null => false, :default => 'debug'
    t.text   :descriptions
    t.datetime :created_on
    t.datetime :updated_at
  end
  
 
end
