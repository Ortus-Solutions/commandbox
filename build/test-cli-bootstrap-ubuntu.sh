#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
box_binary=${BOX_BINARY:-"$repo_root/build/dist/box"}
bx_cli_module=${BX_CLI_MODULE:-"$HOME/.boxlang/modules/bx-cli"}
boxlang_source=${BOXLANG_SOURCE:-"$repo_root/src/cfml/system"}
volume="commandbox-cli-bootstrap-$RANDOM"

cleanup() {
	docker volume rm "$volume" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --rm \
	-v "$box_binary:/mnt/box:ro" \
	-v "$bx_cli_module:/root/.boxlang/modules/bx-cli" \
	-v "$boxlang_source:/mnt/host/c/Users/brad/Documents/GitHub/commandbox/src/cfml/system" \
	-v "$volume:/root/.CommandBox" \
	ubuntu:24.04 sh -s <<'CONTAINER_SCRIPT'
set -eu
echo "[ubuntu] Installing Java..."
apt-get update
apt-get install --yes --no-install-recommends openjdk-21-jre-headless curl unzip jq >/dev/null
cp /mnt/box /usr/local/bin/box
chmod 755 /usr/local/bin/box

export BOXLANG_INSTALL_HOME=/tmp/boxlang-test-install
rm -rf "$BOXLANG_INSTALL_HOME"
echo "[ubuntu] Running real installer smoke test..."
/usr/local/bin/box -clidebug version | tee /tmp/box-output
! grep -q '\[clidebug\] BoxLang command:.*-clidebug' /tmp/box-output
test -x "$BOXLANG_INSTALL_HOME/bin/boxlang"
echo "PASS: Ubuntu real installer"
CONTAINER_SCRIPT
