class CreateSubjectMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :subject_mappings do |t|
      t.string :raw_subject, null: false
      t.string :canonical_subject
      t.string :source, null: false, default: "config"
      t.timestamps
    end
    add_index :subject_mappings, :raw_subject, unique: true
  end
end
