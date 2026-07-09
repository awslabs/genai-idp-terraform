#!/bin/bash
# Setup script for GenAIIDP Starlight documentation site
# Creates symlinks from existing docs/ and images/ into the Starlight content structure
# This avoids any content duplication — docs live in their original location

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTENT_DOCS="$SCRIPT_DIR/src/content/docs"
CONTENT_ROOT="$SCRIPT_DIR/src/content"

echo "📁 Setting up GenAIIDP documentation site..."
echo "   Project root: $PROJECT_ROOT"
echo "   Content docs: $CONTENT_DOCS"

# Ensure content/docs directory exists
mkdir -p "$CONTENT_DOCS"

# Step 1: Symlink all .md files from docs/ into src/content/docs/
# Path: docs-site/src/content/docs/ → 4 levels up to project root
echo ""
echo "🔗 Creating symlinks for documentation files..."
count=0
for md_file in "$PROJECT_ROOT"/docs/*.md; do
    filename=$(basename "$md_file")
    # Skip README.md — we have our own index.mdx landing page
    if [ "$filename" = "README.md" ]; then
        continue
    fi
    target="$CONTENT_DOCS/$filename"
    # Remove existing symlink if present
    [ -L "$target" ] && rm "$target"
    ln -s "../../../../docs/$filename" "$target"
    count=$((count + 1))
done
echo "   ✅ Linked $count documentation files"

# Step 2: Symlink images/ into src/content/images/ (for ../images/ relative paths in docs)
# Path: docs-site/src/content/ → 3 levels up to project root
echo ""
echo "🖼️  Setting up image symlinks..."
[ -L "$CONTENT_ROOT/images" ] && rm "$CONTENT_ROOT/images"
ln -s "../../../images" "$CONTENT_ROOT/images"
echo "   ✅ Linked images directory for relative paths"

# Also put images in public/ for absolute path references
# Path: docs-site/public/ → 2 levels up to project root
mkdir -p "$SCRIPT_DIR/public"
[ -L "$SCRIPT_DIR/public/images" ] && rm "$SCRIPT_DIR/public/images"
ln -s "../../images" "$SCRIPT_DIR/public/images"
echo "   ✅ Linked images directory for public serving"

echo ""
echo "✨ Setup complete! Run 'npm install && npm run dev' to start the dev server."
