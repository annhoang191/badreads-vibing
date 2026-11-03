class CreateGoodreadsProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :goodreads_profiles do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :goodreads_user_id, null: false
      t.boolean :rss_enabled, null: false, default: false
      t.datetime :last_synced_at
      t.integer :consecutive_failures, null: false, default: 0
      t.text :last_error
      t.timestamps
    end
  end
end
