class CreateAcceptanceSubmissions < ActiveRecord::Migration[8.1]
  def up
    create_table :acceptance_submissions do |t|
      t.references :delivery_note, null: false, foreign_key: true
      t.references :attachment, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.datetime :submitted_at, null: false
      t.string :submitted_ip
      t.datetime :reviewed_at
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :acceptance_submissions, :delivery_note_id, unique: true,
              where: "status = 'pending'", name: "index_one_pending_submission_per_note"
  end

  def down
    drop_table :acceptance_submissions
  end
end
