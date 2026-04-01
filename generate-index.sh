#!/bin/bash
# generate-index.sh — Builds sandbox/index.html from manifest.json
# Usage: ./generate-index.sh [output_dir]
#   output_dir defaults to ./files/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.json"
OUTPUT_DIR="${1:-$SCRIPT_DIR/files}"

if [ ! -f "$MANIFEST" ]; then
  echo "Error: manifest.json not found at $MANIFEST"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Count total and live entries
TOTAL=$(jq length "$MANIFEST")
LIVE=$(jq '[.[] | select(.status != "pending")] | length' "$MANIFEST")

cat > "$OUTPUT_DIR/index.html" <<'HEADER'
<!DOCTYPE html>
<html>
<head>
<title>Sandbox — Visualization Index</title>
<style>
  body { background: white; font-family: Times New Roman, serif; margin: 40px; }
  h1 { font-size: 1.4em; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid black; padding: 4px 8px; text-align: left; vertical-align: top; }
  th { background: #ddd; }
  a { color: blue; }
  .pending { color: #999; font-style: italic; }
  .footer { margin-top: 20px; font-size: 0.85em; color: #555; }
</style>
</head>
<body>
<h1>Sandbox &mdash; Visualization Index</h1>
<table>
  <tr>
    <th>#</th>
    <th>File</th>
    <th>Type</th>
    <th>Project/Origin</th>
    <th>Summary</th>
    <th>Date</th>
  </tr>
HEADER

# Generate table rows from manifest
ROW=0
jq -c '.[]' "$MANIFEST" | while IFS= read -r entry; do
  ROW=$((ROW + 1))
  FILE=$(echo "$entry" | jq -r '.file')
  TYPE=$(echo "$entry" | jq -r '.type')
  PROJECT=$(echo "$entry" | jq -r '.project')
  SUMMARY=$(echo "$entry" | jq -r '.summary')
  DATE=$(echo "$entry" | jq -r '.date')
  STATUS=$(echo "$entry" | jq -r '.status // "live"')

  if [ "$STATUS" = "pending" ]; then
    cat >> "$OUTPUT_DIR/index.html" <<ROW_HTML
  <tr class="pending">
    <td>${ROW}</td>
    <td>${FILE} (pending)</td>
    <td>${TYPE}</td>
    <td>${PROJECT}</td>
    <td>${SUMMARY}</td>
    <td>${DATE}</td>
  </tr>
ROW_HTML
  else
    cat >> "$OUTPUT_DIR/index.html" <<ROW_HTML
  <tr>
    <td>${ROW}</td>
    <td><a href="./${FILE}">${FILE}</a></td>
    <td>${TYPE}</td>
    <td>${PROJECT}</td>
    <td>${SUMMARY}</td>
    <td>${DATE}</td>
  </tr>
ROW_HTML
  fi
done

cat >> "$OUTPUT_DIR/index.html" <<FOOTER
</table>
<p class="footer">Sandbox &mdash; wangreport.com | Files published from Claude sessions</p>
</body>
</html>
FOOTER

echo "Generated $OUTPUT_DIR/index.html ($TOTAL entries, $LIVE live)"
