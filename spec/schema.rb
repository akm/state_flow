ActiveRecord::Schema.define(:version => 0) do
  # Users are created and updated by other Users
  create_table :pages, :force => true do |t|
    t.column :name,           :string
    t.column :status_cd ,     :string
    t.column :created_on,     :datetime
    t.column :updated_at,     :datetime
  end
 
end
