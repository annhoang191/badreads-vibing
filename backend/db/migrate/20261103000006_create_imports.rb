class CreateImports < ActiveRecord::Migration[8.0]
  def change
    create_table :imports do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :source, null: false
      t.string :status, null: false, default: "pending"
      t.string :filename
      t.jsonb :stats, null: false, default: {}
      t.text :error_message
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :imports, %i[user_id created_at]
  end
end
