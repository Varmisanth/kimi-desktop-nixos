#!/bin/sh
set -eu
APP_DIR=@OUT@/share/kimi-desktop
ELECTRON_SRC=${KIMI_DESKTOP_ELECTRON_DIST:-@ELECTRON_DIST@}
NODE=@NODE@
STAMP="@STAMP@"
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}
ELECTRON_HASH=$(printf '%s' "$ELECTRON_SRC" | sha256sum)
ELECTRON_HASH=${ELECTRON_HASH%% *}
RUN_ID="$STAMP-$ELECTRON_HASH"
RUN_ROOT="$STATE_DIR/kimi-desktop/erun/runtimes"
RUN_DIR="$RUN_ROOT/$RUN_ID"
tmp=""
cleanup() {
	if [ -n "$tmp" ]; then
		rm -rf "$tmp"
	fi
}
runtime_in_use() {
	runtime=$1
	for proc in /proc/[0-9]*; do
		[ "$(readlink "$proc/exe" 2>/dev/null || true)" = "$runtime/electron" ] && return 0
	done
	return 1
}
cleanup_runtimes() {
	runtime=""
	for runtime in "$RUN_ROOT"/*; do
		[ -d "$runtime" ] || continue
		[ -f "$runtime/.kimi-desktop-stamp" ] || continue
		[ "$runtime" = "$RUN_DIR" ] && continue
		if runtime_in_use "$runtime"; then
			continue
		fi
		rm -rf "$runtime"
	done
}
trap cleanup EXIT HUP INT TERM
if [ ! -f "$RUN_DIR/.kimi-desktop-stamp" ]; then
	mkdir -p "$RUN_ROOT"
	tmp="$RUN_ROOT/.$RUN_ID.tmp.$$"
	rm -rf "$tmp"
	mkdir -p "$tmp/resources/resources/runtime"
	cp -r "$ELECTRON_SRC/." "$tmp/"
	chmod -R u+w "$tmp"
	ln -sfn "$APP_DIR/app" "$tmp/resources/app"
	ln -sfn "$APP_DIR/resources-webbridge-extension" "$tmp/resources/webbridge-extension"
	ln -sfn "$NODE" "$tmp/resources/resources/runtime/node"
	printf '%s' "$RUN_ID" >"$tmp/.kimi-desktop-stamp"
	if mv -T "$tmp" "$RUN_DIR" 2>/dev/null; then
		tmp=""
	fi
fi
if [ ! -f "$RUN_DIR/.kimi-desktop-stamp" ]; then
	printf '%s\n' "Kimi Desktop runtime was not published: $RUN_DIR" >&2
	exit 1
fi
cleanup_runtimes
trap - EXIT HUP INT TERM
export DAIMON_BUNDLE_DIR="$APP_DIR/daimon"
: "${SSL_CERT_FILE:=@CERT_FILE@}"
export SSL_CERT_FILE
export NIX_SSL_CERT_FILE="$SSL_CERT_FILE"
export UV_NATIVE_TLS=1
export LD_LIBRARY_PATH="@LIBSTDCPP@${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if [ -n "${KIMI_DESKTOP_OZONE_PLATFORM:-}" ]; then
	exec "$RUN_DIR/electron" "$RUN_DIR/resources/app" --no-sandbox \
		"--ozone-platform=$KIMI_DESKTOP_OZONE_PLATFORM" "$@"
fi
exec "$RUN_DIR/electron" "$RUN_DIR/resources/app" --no-sandbox "$@"
