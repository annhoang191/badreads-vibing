class CreateReadingInsights < ActiveRecord::Migration[8.0]
  def change
    create_table :reading_insights do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.integer :version, null: false, default: 1
      t.jsonb :data, null: false, default: {}
      t.datetime :computed_at
      t.timestamps
    end
  end
end
