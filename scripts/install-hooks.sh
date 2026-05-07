#!/bin/bash
# Install git hooks for this repo (sitemap auto-update on commit).

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_DIR="$REPO_ROOT/.git/hooks"
HOOK_FILE="$HOOK_DIR/pre-commit"

cat > "$HOOK_FILE" <<'EOF'
#!/bin/bash
# Auto-update sitemap.xml <lastmod> when HTML files are staged for commit.
REPO_ROOT="$(git rev-parse --show-toplevel)"
"$REPO_ROOT/scripts/update-sitemap.sh" --staged
EOF

chmod +x "$HOOK_FILE"
echo "✓ pre-commit hook installed at $HOOK_FILE"
