class CreateLanguages < ActiveRecord::Migration[8.0]
  def change
    create_table :languages do |t|
      t.string :iso_code, null: false, limit: 2
      t.string :title, null: false

      t.timestamps
    end

    add_index :languages, :iso_code, unique: true
  end
end
