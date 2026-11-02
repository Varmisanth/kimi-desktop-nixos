#!/bin/sh
set -eu
STATUS_URL=http://127.0.0.1:10086/status
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}
status_timeout_seconds=2
ready_attempts=15
ready_poll_seconds=1
if ! @CURL@ -fsS --max-time "$status_timeout_seconds" "$STATUS_URL" >/dev/null 2>&1; then
	@WEBBRIDGE@ start
	attempts=0
	until @CURL@ -fsS --max-time "$status_timeout_seconds" "$STATUS_URL" >/dev/null 2>&1; do
		attempts=$((attempts + 1))
		if [ "$attempts" -ge "$ready_attempts" ]; then
			printf '%s\n' 'WebBridge daemon did not become ready' >&2
			exit 1
		fi
		@SLEEP@ "$ready_poll_seconds"
	done
fi
if [ -n "${KIMI_WEBBRIDGE_CDP_PORT:-}" ]; then
	set -- --remote-debugging-port="$KIMI_WEBBRIDGE_CDP_PORT" "$@"
fi
exec @CHROME@ \
	--no-first-run \
	--no-default-browser-check \
	--disable-features=Translate \
	--user-data-dir="$STATE_DIR/kimi-desktop/webbridge-chrome" \
	"$@"
