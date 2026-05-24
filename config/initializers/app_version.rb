# Compute the running app version once per process. Passenger spawns fresh
# workers on restart (tmp/restart.txt), so the SHA is refreshed every deploy
# without shelling out to git on each request.
Rails.application.config.x.app_version =
  if Rails.env.test?
    "test-version"
  else
    revision = IO.popen([ "git", "rev-parse", "--short", "HEAD" ], err: File::NULL, chdir: Rails.root.to_s, &:read).to_s.strip
    if $?.success? && !revision.empty?
      "v#{revision}"
    else
      "unknown"
    end
  end
