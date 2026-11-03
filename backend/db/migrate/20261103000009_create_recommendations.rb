class CreateRecommendations < ActiveRecord::Migration[8.0]
  def change
    create_table :recommendations do |t|
      t.references :recommendation_batch, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :book, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :score
      t.text :reason
      t.string :status, null: false, default: "new"
      t.timestamps
    end
    add_index :recommendations, %i[recommendation_batch_id book_id], unique: true
    add_index :recommendations, %i[user_id status]
    add_check_constraint :recommendations, "position BETWEEN 1 AND 10", name: "recommendations_position_range"
  end
end
