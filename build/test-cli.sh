#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
box_binary=${1:-"$script_dir/dist/box"}
boxlang_jar=${2:-"$script_dir/dist/boxlang.jar"}
bx_cli_module=${BX_CLI_MODULE:-"$HOME/.boxlang/modules/bx-cli"}
bx_cli_source=${BX_CLI_SOURCE:-"$script_dir/../src/cfml/system"}
commandbox_home_volume=${COMMANDBOX_HOME_VOLUME:-"bx-cli-test-commandbox-home"}
expected='CommandBox @build.version@'
actual=$(docker run --rm \
	-v "$box_binary:/mnt/box:ro" \
	-v "$boxlang_jar:/mnt/boxlang.jar:ro" \
	-v "$bx_cli_module:/root/.boxlang/modules/bx-cli:ro" \
	-v "$bx_cli_source:/mnt/host/c/Users/brad/Documents/GitHub/commandbox/src/cfml/system" \
	-v "$commandbox_home_volume:/root/.CommandBox" \
	ubuntu:24.04 sh -c 'apt-get update >/dev/null && apt-get install --yes --no-install-recommends openjdk-21-jre-headless >/dev/null && cp /mnt/box /usr/local/bin/box && cp /mnt/boxlang.jar /usr/local/bin/boxlang.jar && chmod 755 /usr/local/bin/box && /usr/local/bin/box version' | tail -n 1)

[ "$actual" = "$expected" ]
printf '%s\n' "$actual"
