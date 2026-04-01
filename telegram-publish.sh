#!/bin/bash
# telegram-publish.sh — Called by Maverick's Telegram handler to publish to sandbox
#
# Usage:
#   telegram-publish.sh --file <path> --project "Name" --summary "Summary" [--name "file.html"]
#   telegram-publish.sh --html-code <path-to-temp-file> --project "Name" --summary "Summary" --name "file.html"
#
# For Telegram file: bot downloads file to /tmp, passes path here
# For Telegram text: handler saves HTML code to /tmp file, passes path here

set -euo pipefail

SANDBOX_DIR="/Users/harrywang/.openclaw/sandbox-pages"

# Source telegram-send for notifications
source /Users/harrywang/.openclaw/telegram-send.sh 2>/dev/null || true

FILE_PATH=""
CODE_PATH=""
PROJECT=""
SUMMARY=""
CUSTOM_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --file) FILE_PATH="$2"; shift 2 ;;
    --html-code) CODE_PATH="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --name) CUSTOM_NAME="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Build args for publish-sandbox.sh
ARGS=()
if [ -n "$FILE_PATH" ]; then
  ARGS+=("$FILE_PATH")
elif [ -n "$CODE_PATH" ]; then
  ARGS+=("$CODE_PATH")
else
  echo "Error: need --file or --html-code"
  exit 1
fi

[ -n "$PROJECT" ] && ARGS+=(--project "$PROJECT")
[ -n "$SUMMARY" ] && ARGS+=(--summary "$SUMMARY")
[ -n "$CUSTOM_NAME" ] && ARGS+=(--name "$CUSTOM_NAME")

# Run publish
OUTPUT=$(bash "$SANDBOX_DIR/publish-sandbox.sh" "${ARGS[@]}" 2>&1) || {
  tg_send "❌ Sandbox publish failed: $OUTPUT" 4
  exit 1
}

# Extract the URL from output
URL=$(echo "$OUTPUT" | grep "^File:" | sed 's/File: //')

tg_send "✅ Published to sandbox: $URL" 4
echo "$OUTPUT"
