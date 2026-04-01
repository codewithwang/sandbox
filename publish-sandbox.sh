#!/bin/bash
# publish-sandbox.sh — Publish an HTML file to sandbox-pages
#
# Usage:
#   ./publish-sandbox.sh <html-file> --project "Name" --summary "One-line summary"
#   ./publish-sandbox.sh <html-file> --project "Name" --summary "Summary" --name "custom-name.html"
#   ./publish-sandbox.sh --html-code "<html>...</html>" --project "Name" --summary "Summary" --name "file.html"
#
# On push, GitHub Action auto-generates index.html and deploys to Pages.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.json"
FILES_DIR="$SCRIPT_DIR/files"

# --- Parse args ---
HTML_FILE=""
HTML_CODE=""
PROJECT=""
SUMMARY=""
CUSTOM_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --project) PROJECT="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --name) CUSTOM_NAME="$2"; shift 2 ;;
    --html-code) HTML_CODE="$2"; shift 2 ;;
    *) HTML_FILE="$1"; shift ;;
  esac
done

if [ -z "$HTML_FILE" ] && [ -z "$HTML_CODE" ]; then
  echo "Usage: $0 <html-file> --project \"Name\" --summary \"Summary\""
  echo "       $0 --html-code \"<html>...\" --project \"Name\" --summary \"Summary\" --name \"file.html\""
  exit 1
fi

if [ -z "$PROJECT" ] || [ -z "$SUMMARY" ]; then
  echo "Error: --project and --summary are required"
  exit 1
fi

# --- Determine filename ---
if [ -n "$CUSTOM_NAME" ]; then
  FILENAME="$CUSTOM_NAME"
elif [ -n "$HTML_FILE" ]; then
  FILENAME="$(basename "$HTML_FILE")"
else
  echo "Error: --name is required when using --html-code"
  exit 1
fi

# Ensure .html extension
if [[ "$FILENAME" != *.html ]]; then
  FILENAME="${FILENAME}.html"
fi

# --- Save file ---
mkdir -p "$FILES_DIR"

if [ -n "$HTML_CODE" ]; then
  echo "$HTML_CODE" > "$FILES_DIR/$FILENAME"
  echo "Saved HTML code as: $FILENAME"
elif [ -n "$HTML_FILE" ]; then
  if [ ! -f "$HTML_FILE" ]; then
    echo "Error: File not found: $HTML_FILE"
    exit 1
  fi
  cp "$HTML_FILE" "$FILES_DIR/$FILENAME"
  echo "Copied file: $FILENAME"
fi

# --- Update manifest ---
DATE=$(date +"%Y-%m-%d")

EXISTS=$(jq --arg f "$FILENAME" '[.[] | select(.file == $f)] | length' "$MANIFEST")
if [ "$EXISTS" -gt 0 ]; then
  jq --arg f "$FILENAME" --arg p "$PROJECT" --arg s "$SUMMARY" --arg d "$DATE" \
    '[.[] | if .file == $f then .project = $p | .summary = $s | .date = $d else . end]' \
    "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
  echo "Updated manifest entry: $FILENAME"
else
  jq --arg f "$FILENAME" --arg p "$PROJECT" --arg s "$SUMMARY" --arg d "$DATE" \
    '[{"file": $f, "type": "HTML", "project": $p, "summary": $s, "date": $d}] + .' \
    "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
  echo "Added manifest entry: $FILENAME"
fi

# --- Commit and push (Action handles index + deploy) ---
cd "$SCRIPT_DIR"
git add -A
if git diff --cached --quiet 2>/dev/null; then
  echo "No changes to commit"
else
  git commit -m "Publish: $FILENAME — $DATE"
  git push origin main 2>/dev/null || git push -u origin main
  echo "Pushed — GitHub Action will deploy in ~30s"
fi

echo ""
echo "Done! Will be live at: https://codewithwang.github.io/sandbox-pages/"
echo "File: https://codewithwang.github.io/sandbox-pages/$FILENAME"
