#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tests_dir="$repo_root/tests/compile-dsl"

docker run --rm \
	-v "$tests_dir:/mnt/tests" \
	ubuntu:24.04 sh -s <<'CONTAINER_SCRIPT'
set -eu
echo "[ubuntu] Adding CommandBox beta apt repository..."
apt-get update >/dev/null
apt-get install --yes --no-install-recommends curl apt-transport-https ca-certificates gnupg >/dev/null
curl -fsSL https://downloads.ortussolutions.com/debs/gpg | gpg --dearmor -o /usr/share/keyrings/ortussolutions.gpg
echo "deb [signed-by=/usr/share/keyrings/ortussolutions.gpg] https://downloads.ortussolutions.com/debs-be/noarch /" > /etc/apt/sources.list.d/commandbox.list
apt-get update >/dev/null
apt-get install --yes commandbox >/dev/null

echo "[ubuntu] Running java run test suite against the installed box..."
cd /mnt/tests
box task run taskFile=RunTask.cfc
echo "PASS: compile-dsl java run tests"
CONTAINER_SCRIPT
