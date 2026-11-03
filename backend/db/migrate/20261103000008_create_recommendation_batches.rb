class CreateRecommendationBatches < ActiveRecord::Migration[8.0]
  def change
    create_table :recommendation_batches do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :status, null: false, default: "pending"
      t.string :ranked_by
      t.string :prompt_version
      t.decimal :total_cost_usd, precision: 10, scale: 6, null: false, default: 0
      t.jsonb :cost_by_tier, null: false, default: {}
      t.integer :agent_turns
      t.text :error_message
      t.timestamps
    end
    add_index :recommendation_batches, %i[user_id created_at]
  end
end
