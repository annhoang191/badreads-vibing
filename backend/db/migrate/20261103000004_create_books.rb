class CreateBooks < ActiveRecord::Migration[8.0]
  def change
    create_table :books do |t|
      t.string :source, null: false, default: "goodreads"
      t.string :goodreads_book_id
      t.string :isbn
      t.string :isbn13
      t.string :title, null: false
      t.string :author
      t.string :additional_authors, array: true, null: false, default: []
      t.integer :num_pages
      t.integer :year_published
      t.integer :original_publication_year
      t.decimal :avg_rating, precision: 3, scale: 2
      t.string :open_library_work_key
      t.jsonb :subjects, null: false, default: []
      t.string :cover_url
      t.string :enrichment_status, null: false, default: "pending"
      t.datetime :enriched_at
      t.timestamps
    end
    add_index :books, :goodreads_book_id, unique: true, where: "goodreads_book_id IS NOT NULL"
    add_index :books, :open_library_work_key, unique: true, where: "open_library_work_key IS NOT NULL"
    add_index :books, :isbn13
  end
end
