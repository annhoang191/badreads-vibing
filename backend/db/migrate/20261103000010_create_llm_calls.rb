class CreateLlmCalls < ActiveRecord::Migration[8.0]
  def change
    create_table :llm_calls do |t|
      t.references :recommendation_batch, foreign_key: { on_delete: :cascade }
      t.string :task, null: false
      t.string :tier, null: false
      t.string :model, null: false
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.integer :cache_read_tokens, null: false, default: 0
      t.integer :cache_write_tokens, null: false, default: 0
      t.decimal :cost_usd, precision: 10, scale: 6, null: false, default: 0
      t.integer :latency_ms
      t.string :stop_reason
      t.text :error
      t.timestamps
    end
    add_index :llm_calls, %i[task created_at]
  end
end
