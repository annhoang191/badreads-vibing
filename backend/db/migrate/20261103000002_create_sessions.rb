class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :token, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :sessions, :token, unique: true
  end
end
