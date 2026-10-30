#!/bin/bash
# Middaw.app's executable. Starts Middaw's server if it is not already running,
# then opens Middaw in a window of its own. The server stops by itself a few
# minutes after the last Middaw window closes.
ROOT="__MIDDAW_ROOT__"
PORT=8765
URL="http://127.0.0.1:$PORT/"
LOG="$HOME/Library/Logs/Middaw.log"

alert() {
  /usr/bin/osascript -e "display alert \"Middaw\" message \"$1\" as critical" >/dev/null 2>&1
}

if [ ! -f "$ROOT/server/app.py" ]; then
  alert "Middaw's folder has moved from $ROOT. Run tools/mac/make_app.sh in its new place to make the app again."
  exit 1
fi

# A Python 3.9 or newer: Homebrew's (Apple silicon, then Intel) or the Mac's own.
PY=""
for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
  [ -x "$candidate" ] || continue
  if [ "$candidate" = /usr/bin/python3 ] && ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
    continue   # the Mac's python3 is only a stub until the Command Line Tools are in
  fi
  if "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 9))' 2>/dev/null; then
    PY="$candidate"; break
  fi
done
if [ -z "$PY" ]; then
  alert "Middaw needs Python 3.9 or newer. Click Install in the window that follows to get Apple's Command Line Tools, which include it, then open Middaw again."
  /usr/bin/xcode-select --install >/dev/null 2>&1
  exit 1
fi

alive() { /usr/bin/curl -fs -o /dev/null "$URL/api/alive"; }

if ! alive; then
  mkdir -p "$(dirname "$LOG")"
  cd "$ROOT" || exit 1
  nohup "$PY" server/app.py --port "$PORT" --quit-when-idle 180 >>"$LOG" 2>&1 &
  for _ in $(seq 1 50); do alive && break; sleep 0.2; done
  if ! alive; then
    alert "Middaw's server did not start. Details are in ~/Library/Logs/Middaw.log."
    exit 1
  fi
fi

# A window of its own in Chrome or Edge (they have Web MIDI, for a MIDI
# keyboard); otherwise the default browser.
for browser in "Google Chrome" "Microsoft Edge" "Chromium" "Brave Browser"; do
  if [ -d "/Applications/$browser.app" ] || [ -d "$HOME/Applications/$browser.app" ]; then
    exec /usr/bin/open -na "$browser" --args --app="$URL"
  fi
done
exec /usr/bin/open "$URL"
