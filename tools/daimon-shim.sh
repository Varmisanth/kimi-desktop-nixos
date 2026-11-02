#!/bin/sh
set -eu
NODE=@NODE@
UV=@UV@
PYTHON=@PYTHON@
bundle_root=$(CDPATH='' cd -P "${0%/*}/.." && pwd)
cli="$bundle_root/app/daimon/dist/src/runner/cli.js"
export PATH="@SHIM_PATH@${PATH:+:$PATH}"
case "${1:-}" in
--node | --node-bin)
	[ "$#" -ge 2 ] || exit 64
	shift 2
	;;
--node=* | --node-bin=*) shift ;;
esac
if [ "${1:-}" = "--background-python-sync" ]; then
	export DAIMON_PYTHON_RUNTIME_BACKGROUND_SYNC=1
	shift
fi
[ "${1:-}" = "--" ] && shift
if [ "${1:-}" = "runtime" ] && [ -z "${2:-}" ]; then
	set -- start --control
fi
if [ "${1:-}" = "setup" ] || [ "${1:-}" = "onboard" ]; then
	has_workspace=0
	for arg; do
		case "$arg" in
		--workspace-dir | --workspace-dir=*)
			has_workspace=1
			break
			;;
		esac
	done
	if [ "$has_workspace" -eq 0 ] && [ -n "${KIMI_DESKTOP_WORKSPACE_DIR:-}" ]; then
		set -- "$@" --workspace-dir "$KIMI_DESKTOP_WORKSPACE_DIR"
	fi
fi
: "${KIMI_SHARE_DIR:=${HOME}/.kimi}"
: "${DAIMON_CONFIG_PATH:=${KIMI_SHARE_DIR}/daimon/config.json}"
: "${OPENCLAW_CONFIG_PATH:=${KIMI_SHARE_DIR}/daimon/runtime/openclaw-empty.json}"
export KIMI_SHARE_DIR DAIMON_CONFIG_PATH OPENCLAW_CONFIG_PATH
export DAIMON_BUNDLE_NODE_BIN="$NODE"
export DAIMON_NODE_BIN="$NODE"
export DAIMON_UV_PATH="$UV"
export DAIMON_PYTHON_BASE_PATH="$PYTHON"
export DAIMON_RUNTIME_BINARY_PATH="$bundle_root/bin/kimi-daimon"
export DAIMON_ADAPTER_PACKAGE_ROOT="$bundle_root/app/daimon"
if [ -d "$bundle_root/app/daimon/assets/builtin-skills" ]; then
	export KIMI_BUILTIN_SKILLS_DIR="$bundle_root/app/daimon/assets/builtin-skills"
fi
: "${SSL_CERT_FILE:=@CERT_FILE@}"
export SSL_CERT_FILE
export NIX_SSL_CERT_FILE="$SSL_CERT_FILE"
export UV_NATIVE_TLS=1
export LD_LIBRARY_PATH="@LIBSTDCPP@${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$NODE" "$cli" "$@"
