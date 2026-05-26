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

# bin/abt-fop-container is now tracked in the repo as the canonical
# containerized launcher; no wrapper generation needed.
FOP_BINARY="$PROJECT_ROOT/bin/abt-fop-container"

echo "✅ FOP container image built: $FOP_IMAGE_NAME"
echo "✅ Using tracked wrapper at: $FOP_BINARY"

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

echo "🧪 Testing Rails<->FOP integration..."
if bundle exec rails test test/integration/fop_installation_test.rb; then
  echo "✅ Rails<->FOP integration looks good."
else
  echo "❌ Rails<->FOP integration needs checking."
  exit 1
fi
