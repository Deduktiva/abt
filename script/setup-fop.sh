#!/bin/bash
# FOP Installation and Setup Script for ABT Invoice System

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔧 Setting up Apache FOP for PDF generation..."

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS with Podman
  echo "🐳 Setting up FOP via Podman (macOS)..."
  
  if ! command -v podman &> /dev/null; then
    echo "❌ Podman not found. Installing via Homebrew..."
    if ! command -v brew &> /dev/null; then
      echo "❌ Homebrew not found. Please install Homebrew first."
      exit 1
    fi
    brew install podman
    podman machine init
    podman machine start
  fi
  
  # Create FOP wrapper script
  FOP_WRAPPER="$PROJECT_ROOT/bin/fop"
  mkdir -p "$PROJECT_ROOT/bin"
  
  cat > "$FOP_WRAPPER" << 'EOF'
#!/bin/bash
# FOP wrapper for Podman on macOS
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

podman run --rm \
  -v "$PROJECT_ROOT:/workspace" \
  -w /workspace \
  debian:trixie-slim \
  bash -c "
    apt-get update -qq && apt-get install -y -qq fop libsaxon-java && 
    JAVA_OPTS='-Djavax.xml.transform.TransformerFactory=net.sf.saxon.TransformerFactoryImpl' \
    fop \"\$@\"
  " -- "$@"
EOF
  
  chmod +x "$FOP_WRAPPER"
  FOP_BINARY="$FOP_WRAPPER"
  
  echo "✅ FOP Podman wrapper created at: $FOP_BINARY"
  
else
  # Production Linux (Debian Trixie/Ubuntu)
  echo "📦 Installing FOP via apt (Debian Trixie/Ubuntu)..."
  echo "ℹ️  Note: Requires Debian Trixie (13) or newer for FOP 2.10+dfsg-2"
  
  # Update package list
  sudo apt-get update
  
  # Install FOP and Saxon
  sudo apt-get install -y fop libsaxon-java
  
  FOP_BINARY="/usr/bin/fop"
  echo "✅ FOP installed via apt at: $FOP_BINARY"
fi

# Create settings configuration
echo "⚙️  Configuring application settings..."
SETTINGS_FILE="$PROJECT_ROOT/config/settings/development.yml"

if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  cat > "$SETTINGS_FILE" << EOF
fop:
  binary_path: "$FOP_BINARY"

payments:
  public_url: "http://localhost:3000/payments/%token%"
EOF
  echo "✅ Created development settings file"
else
  echo "⚠️  Settings file already exists. Please manually add:"
  echo "fop:"
  echo "  binary_path: \"$FOP_BINARY\""
fi

# Test installation
echo "🧪 Testing FOP installation..."
if "$FOP_BINARY" -version; then
  echo "✅ FOP installation successful!"
else
  echo "❌ FOP installation failed"
  exit 1
fi

echo ""
echo "🎉 FOP setup complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Update your settings files with the FOP binary path: $FOP_BINARY"
echo "   2. Run: rails test test/system/fop_installation_test.rb"
echo "   3. Test PDF generation in your application"
echo ""