# Compute the running app version once per process. Puma is restarted on
# every deploy (systemctl --user reload abt-puma.service → SIGUSR2), so the
# SHA is refreshed without shelling out to git on each request.
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
