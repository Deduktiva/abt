namespace :db do
  desc "Dump the primary database to a timestamped pg_dump file in backups/ (PostgreSQL only; cache/queue databases are not dumped)"
  task backup: :environment do
    config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary")
    abort "No primary database configured for #{Rails.env}." if config.nil?

    settings = config.configuration_hash
    unless settings[:adapter].to_s.start_with?("postgresql")
      abort "db:backup requires PostgreSQL, but the primary database for #{Rails.env} uses adapter #{settings[:adapter].inspect}."
    end

    dir = Pathname.new(ENV["ABT_BACKUP_DIR"].presence || Rails.root.join("backups").to_s)
    FileUtils.mkdir_p(dir, mode: 0o700)

    timestamp = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
    target = dir.join("#{settings[:database]}-#{timestamp}.dump")
    partial = Pathname.new("#{target}.part")

    command = [
      "pg_dump",
      "--format=custom",
      "--no-owner",
      "--no-privileges",
      "--file=#{partial}"
    ]
    command << "--host=#{settings[:host]}" if settings[:host].present?
    command << "--port=#{settings[:port]}" if settings[:port].present?
    command << "--username=#{settings[:username]}" if settings[:username].present?
    command << "--dbname=#{settings[:database]}"

    env = {}
    env["PGPASSWORD"] = settings[:password].to_s if settings[:password].present?

    puts "Dumping #{settings[:database]} to #{target} ..."
    unless system(env, *command)
      FileUtils.rm_f(partial)
      abort "pg_dump failed; no backup written. Is the postgresql-client package installed and the database reachable?"
    end

    File.chmod(0o600, partial)
    FileUtils.mv(partial, target)
    puts "Wrote #{target} (#{ActiveSupport::NumberHelper.number_to_human_size(target.size)})."
    puts "Restore with: pg_restore --clean --if-exists --no-owner --dbname=#{settings[:database]} #{target}"
  end
end
