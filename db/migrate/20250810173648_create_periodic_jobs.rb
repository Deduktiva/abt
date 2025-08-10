class CreatePeriodicJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :periodic_jobs do |t|
      t.string :name, null: false
      t.text :description
      t.string :class_name, null: false
      t.boolean :enabled, default: true, null: false
      t.string :schedule, null: false
      t.datetime :last_run_at
      t.datetime :next_run_at

      t.timestamps
    end

    add_index :periodic_jobs, :name, unique: true
    add_index :periodic_jobs, :enabled
    add_index :periodic_jobs, :next_run_at
  end
end
