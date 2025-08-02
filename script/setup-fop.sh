#!/bin/bash
# FOP Installation and Setup Script for ABT Invoice System

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FOP_IMAGE_NAME="abt-fop"
FOP_CONTAINER_NAME="abt-fop-service"

echo "🔧 Setting up Apache FOP for PDF generation..."

# Detect container runtime
CONTAINER_CMD=""
if command -v podman &> /dev/null; then
  CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
  CONTAINER_CMD="docker"
fi

# Check if running on macOS or want containerized solution
if [[ "$OSTYPE" == "darwin"* ]] || [[ "${1:-}" == "--container" ]]; then
  # Containerized FOP (macOS default, or explicit request)
  echo "🐳 Setting up containerized FOP..."
  
  if [[ -z "$CONTAINER_CMD" ]]; then
    echo "❌ Neither Podman nor Docker found. Installing Podman via Homebrew..."
    if ! command -v brew &> /dev/null; then
      echo "❌ Homebrew not found. Please install Homebrew first."
      exit 1
    fi
    brew install podman
    podman machine init
    podman machine start
    CONTAINER_CMD="podman"
  fi
  
  echo "📦 Building FOP container image..."
  $CONTAINER_CMD build -f "$PROJECT_ROOT/Dockerfile.fop" -t "$FOP_IMAGE_NAME" "$PROJECT_ROOT"
  
  # Create FOP wrapper script
  FOP_WRAPPER="$PROJECT_ROOT/bin/fop"
  mkdir -p "$PROJECT_ROOT/bin"
  
  cat > "$FOP_WRAPPER" << EOF
#!/bin/bash
# FOP wrapper for containerized execution
PROJECT_ROOT="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"

# Use either podman or docker
CONTAINER_CMD="$CONTAINER_CMD"

# Run FOP in container with project directory mounted
\$CONTAINER_CMD run --rm \\
  -v "\$PROJECT_ROOT:/workspace" \\
  -w /workspace \\
  $FOP_IMAGE_NAME \\
  "\$@"
EOF
  
  chmod +x "$FOP_WRAPPER"
  FOP_BINARY="$FOP_WRAPPER"
  
  echo "✅ FOP container image built: $FOP_IMAGE_NAME"
  echo "✅ FOP wrapper created at: $FOP_BINARY"
  
  # Optional: Create a persistent service container for even faster execution
  if [[ "${2:-}" == "--service" ]]; then
    echo "🚀 Setting up persistent FOP service container..."
    
    # Stop existing service if running
    $CONTAINER_CMD stop "$FOP_CONTAINER_NAME" 2>/dev/null || true
    $CONTAINER_CMD rm "$FOP_CONTAINER_NAME" 2>/dev/null || true
    
    # Start persistent container in background
    $CONTAINER_CMD run -d \\
      --name "$FOP_CONTAINER_NAME" \\
      -v "$PROJECT_ROOT:/workspace" \\
      -w /workspace \\
      "$FOP_IMAGE_NAME" \\
      tail -f /dev/null
    
    # Create service wrapper
    cat > "$FOP_WRAPPER" << EOF
#!/bin/bash
# FOP service wrapper for fastest execution
PROJECT_ROOT="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"

# Execute FOP in persistent container
$CONTAINER_CMD exec "$FOP_CONTAINER_NAME" fop "\$@"
EOF
    
    echo "✅ FOP service container started: $FOP_CONTAINER_NAME"
    echo "💡 Use '$CONTAINER_CMD stop $FOP_CONTAINER_NAME' to stop the service"
  fi
  
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