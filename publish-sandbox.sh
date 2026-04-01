#!/bin/bash
# publish-sandbox.sh — Publish an HTML file to wangreport.com/sandbox
#
# Usage:
#   ./publish-sandbox.sh <html-file> --project "Project Name" --summary "One-line summary"
#   ./publish-sandbox.sh <html-file> --project "Project Name" --summary "Summary" --name "custom-name.html"
#   ./publish-sandbox.sh --regenerate   (just rebuild index from manifest and deploy)
#
# The script:
#   1. Copies the HTML file into sandbox-pages/files/
#   2. Adds an entry to manifest.json
#   3. Regenerates index.html from manifest
#   4. Copies everything to wang-report/deploy/sandbox/
#   5. Commits and pushes both repos

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.json"
FILES_DIR="$SCRIPT_DIR/files"
DEPLOY_SANDBOX="/Users/harrywang/.openclaw/wang-report/deploy/sandbox"

# --- Parse args ---
REGEN_ONLY=false
HTML_FILE=""
PROJECT=""
SUMMARY=""
CUSTOM_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --regenerate) REGEN_ONLY=true; shift ;;
    --project) PROJECT="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --name) CUSTOM_NAME="$2"; shift 2 ;;
    *) HTML_FILE="$1"; shift ;;
  esac
done

if [ "$REGEN_ONLY" = false ] && [ -z "$HTML_FILE" ]; then
  echo "Usage: $0 <html-file> --project \"Name\" --summary \"Summary\""
  echo "       $0 --regenerate"
  exit 1
fi

# --- Add new file ---
if [ "$REGEN_ONLY" = false ]; then
  if [ ! -f "$HTML_FILE" ]; then
    echo "Error: File not found: $HTML_FILE"
    exit 1
  fi

  if [ -z "$PROJECT" ] || [ -z "$SUMMARY" ]; then
    echo "Error: --project and --summary are required"
    exit 1
  fi

  # Determine filename
  if [ -n "$CUSTOM_NAME" ]; then
    FILENAME="$CUSTOM_NAME"
  else
    FILENAME="$(basename "$HTML_FILE")"
  fi

  # Ensure .html extension
  if [[ "$FILENAME" != *.html ]]; then
    FILENAME="${FILENAME}.html"
  fi

  # Copy file
  mkdir -p "$FILES_DIR"
  cp "$HTML_FILE" "$FILES_DIR/$FILENAME"

  # Get today's date
  DATE=$(date +"%Y-%m")

  # Check if entry already exists, update or add
  EXISTS=$(jq --arg f "$FILENAME" '[.[] | select(.file == $f)] | length' "$MANIFEST")
  if [ "$EXISTS" -gt 0 ]; then
    # Update existing entry
    jq --arg f "$FILENAME" --arg p "$PROJECT" --arg s "$SUMMARY" --arg d "$DATE" \
      '[.[] | if .file == $f then .project = $p | .summary = $s | .date = $d | .status = "live" else . end]' \
      "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
    echo "Updated existing entry: $FILENAME"
  else
    # Add new entry at the top
    jq --arg f "$FILENAME" --arg p "$PROJECT" --arg s "$SUMMARY" --arg d "$DATE" \
      '[{"file": $f, "type": "HTML", "project": $p, "summary": $s, "date": $d, "status": "live"}] + .' \
      "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
    echo "Added new entry: $FILENAME"
  fi
fi

# --- Regenerate index ---
echo "Regenerating index.html..."
bash "$SCRIPT_DIR/generate-index.sh" "$FILES_DIR"

# --- Deploy to wang-report ---
echo "Deploying to wang-report/deploy/sandbox/..."
mkdir -p "$DEPLOY_SANDBOX"

# Copy all HTML files (not just the new one)
cp "$FILES_DIR"/*.html "$DEPLOY_SANDBOX/" 2>/dev/null || true

# --- Commit sandbox-pages repo ---
cd "$SCRIPT_DIR"
git add -A
if git diff --cached --quiet 2>/dev/null; then
  echo "No changes to commit in sandbox-pages"
else
  git commit -m "Publish: ${FILENAME:-regenerate index} — $(date +%Y-%m-%d)"
  git push origin main 2>/dev/null || git push -u origin main
  echo "Pushed sandbox-pages"
fi

# --- Commit wang-report deploy ---
cd /Users/harrywang/.openclaw/wang-report/deploy
git add sandbox/
if git diff --cached --quiet 2>/dev/null; then
  echo "No changes to commit in wang-report"
else
  git commit -m "Sandbox update: ${FILENAME:-regenerate} — $(date +%Y-%m-%d)"
  git push 2>/dev/null || git push --set-upstream origin main
  echo "Pushed wang-report"
fi

echo ""
echo "Done! Live at: https://wangreport.com/sandbox/"
if [ "$REGEN_ONLY" = false ]; then
  echo "File: https://wangreport.com/sandbox/$FILENAME"
fi
