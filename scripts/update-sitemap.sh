#!/bin/bash
# Update sitemap.xml <lastmod> for HTML files that changed in this commit.
# Run as pre-commit hook or manually.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SITEMAP="$REPO_ROOT/sitemap.xml"
TODAY="$(date -u +%Y-%m-%d)"

if [ ! -f "$SITEMAP" ]; then
  echo "sitemap.xml not found at $SITEMAP" >&2
  exit 1
fi

# Detect changed HTML files (staged for pre-commit, or all *.html for manual run)
if [ "${1:-}" = "--staged" ]; then
  CHANGED=$(git diff --cached --name-only --diff-filter=ACMR | /usr/bin/grep -E '\.html$' || true)
else
  # Manual mode: rebuild lastmod for all html in sitemap
  CHANGED=$(git diff --name-only HEAD --diff-filter=ACMR | /usr/bin/grep -E '\.html$' || true)
fi

if [ -z "$CHANGED" ]; then
  echo "No HTML changes detected. sitemap.xml unchanged."
  exit 0
fi

echo "Changed HTML files:"
echo "$CHANGED" | sed 's/^/  - /'

# For each changed HTML, update <lastmod> in sitemap.xml
# Match by URL path containing the filename (without query)
UPDATED=0
while IFS= read -r FILE; do
  # Skip empty
  [ -z "$FILE" ] && continue

  # Map filename to URL path
  case "$FILE" in
    index.html)
      # Root URL: ends with /
      PATTERN='<loc>https://kabe-wall.github.io/etude-support/</loc>'
      ;;
    *)
      PATTERN="<loc>https://kabe-wall.github.io/etude-support/$FILE</loc>"
      ;;
  esac

  # If this URL is in sitemap, update its <lastmod>
  if /usr/bin/grep -qF "$PATTERN" "$SITEMAP"; then
    # Use awk to replace lastmod within the matching <url> block
    awk -v pattern="$PATTERN" -v today="$TODAY" '
      BEGIN { in_url = 0; matched = 0 }
      /<url>/ { in_url = 1; buffer = ""; matched = 0 }
      in_url { buffer = buffer $0 "\n" }
      $0 ~ pattern && in_url { matched = 1 }
      /<\/url>/ {
        in_url = 0
        if (matched) {
          # Replace existing <lastmod>
          gsub(/<lastmod>[^<]+<\/lastmod>/, "<lastmod>" today "</lastmod>", buffer)
        }
        printf "%s", buffer
        next
      }
      !in_url { print }
    ' "$SITEMAP" > "$SITEMAP.tmp"
    mv "$SITEMAP.tmp" "$SITEMAP"
    UPDATED=$((UPDATED + 1))
    echo "  Updated lastmod for $FILE"
  fi
done <<< "$CHANGED"

if [ $UPDATED -gt 0 ]; then
  if [ "${1:-}" = "--staged" ]; then
    git add "$SITEMAP"
    echo "sitemap.xml updated and staged."
  else
    echo "sitemap.xml updated. Don't forget to commit."
  fi
else
  echo "No matching URLs found in sitemap.xml."
fi
