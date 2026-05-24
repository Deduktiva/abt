#!/bin/bash
# SessionStart hook for Claude Code on the web.
#
# Sets up Apache FOP natively (no Docker), since the sandbox doesn't
# expose a container runtime. The dev/test Rails config expects a FOP
# binary at ./bin/abt-fop-container — we create a thin wrapper there
# that runs the Debian/Ubuntu fop package with Saxon on the classpath.
set -euo pipefail

# Only run inside the remote sandbox; local dev should use script/setup-fop.sh.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

echo "== Installing system packages (fop, saxon, java-wrappers) =="
export DEBIAN_FRONTEND=noninteractive
if ! dpkg -s fop libsaxonb-java java-wrappers openjdk-21-jre-headless >/dev/null 2>&1; then
  # Disable broken third-party PPAs that block apt-get update in the sandbox.
  for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    [ -e "$f" ] || continue
    case "$f" in
      *deadsnakes*|*ondrej*) mv "$f" "$f.disabled" ;;
    esac
  done
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends \
    fop \
    libsaxonb-java \
    java-wrappers \
    openjdk-21-jre-headless
fi

echo "== Installing Ruby gems =="
bundle install --quiet

echo "== Seeding config/database.yml from sample (if missing) =="
if [ ! -f config/database.yml ]; then
  cp config/database.yml.sample config/database.yml
fi

echo "== Verifying chromium for system tests =="
# BROWSER_PATH is set in .claude/settings.json to the version-stable
# Playwright chromium symlink; we just sanity-check it here.
if [ -x "${BROWSER_PATH:-/opt/pw-browsers/chromium}" ]; then
  "${BROWSER_PATH:-/opt/pw-browsers/chromium}" --version
else
  echo "WARNING: chromium not found at ${BROWSER_PATH:-/opt/pw-browsers/chromium} — system tests will fail until BROWSER_PATH is fixed."
fi

echo "== Creating FOP wrapper at ./bin/abt-fop-container =="
mkdir -p bin
cat > bin/abt-fop-container << 'WRAPPER'
#!/bin/sh
# FOP wrapper for the Claude Code sandbox.
# Runs the system fop (Debian/Ubuntu package) with Saxon-B injected as
# the XSLT TransformerFactory so XSLT 2.0 stylesheets work.
. /usr/lib/java-wrappers/java-wrappers.sh

JAVA_ARGS="-Dfop.skipDynamicClasspath=true -Djava.awt.headless=true -Djavax.xml.transform.TransformerFactory=net.sf.saxon.TransformerFactoryImpl"

find_java_runtime
find_jars saxonb fop fop-core fop-events fop-util fop-transcoder /usr/share/fop/fop-hyph.jar
find_jars commons-io commons-logging xmlgraphics-commons xercesImpl xml-apis xml-apis-ext fontbox2 batik-all

if [ -n "${FOP_EXTRA_JAR_PATH:-}" ]; then
  find_jars "$FOP_EXTRA_JAR_PATH"/*.jar
fi

run_java org.apache.fop.cli.Main "$@"
WRAPPER
chmod +x bin/abt-fop-container

echo "== Verifying FOP wrapper =="
./bin/abt-fop-container -version

echo "== FOP setup complete =="
