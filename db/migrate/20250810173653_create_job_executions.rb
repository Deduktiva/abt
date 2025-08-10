class CreateJobExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :job_executions do |t|
      t.references :periodic_job, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.string :status, null: false, default: 'running'
      t.text :output
      t.text :error_message

      t.timestamps
    end

    add_index :job_executions, [:periodic_job_id, :started_at]
    add_index :job_executions, :status
  end
end
