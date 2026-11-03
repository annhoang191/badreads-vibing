class CreateUserBooks < ActiveRecord::Migration[8.0]
  def change
    create_table :user_books do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :book, null: false, foreign_key: true
      t.string :exclusive_shelf, null: false
      t.string :shelves, array: true, null: false, default: []
      t.integer :my_rating
      t.date :date_read
      t.date :date_added
      t.integer :read_count, null: false, default: 0
      t.text :review
      t.timestamps
    end
    add_index :user_books, %i[user_id book_id], unique: true
    add_index :user_books, %i[user_id exclusive_shelf]
    add_check_constraint :user_books, "my_rating IS NULL OR (my_rating BETWEEN 1 AND 5)", name: "user_books_my_rating_range"
  end
end
