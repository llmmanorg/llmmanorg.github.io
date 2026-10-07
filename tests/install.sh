#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
SERVER_PID=
trap 'if [ "$SERVER_PID" ]; then kill "$SERVER_PID" 2>/dev/null || true; fi; rm -rf "$TMP"' EXIT INT TERM

case "$(uname -m)" in
(x86_64|amd64) ARCH=x86_64 ;;
(arm64|aarch64) ARCH=aarch64 ;;
(*) echo "Unsupported test architecture: $(uname -m)" >&2; exit 1 ;;
esac
case "$(uname -s)" in
(Linux) TARGET="${ARCH}-unknown-linux-gnu" ;;
(Darwin) TARGET="aarch64-apple-darwin" ;;
(*) echo "Unsupported test OS: $(uname -s)" >&2; exit 1 ;;
esac

ASSET="llmman-${TARGET}"
RELEASE_DIR="$TMP/http/download/test"
mkdir -p "$RELEASE_DIR"

cat >"$RELEASE_DIR/$ASSET" <<'EOF'
#!/bin/sh
if [ "$1" = "--version" ]; then
	printf 'llmman test\n'
	exit 0
fi
exit 1
EOF

if command -v sha256sum >/dev/null 2>&1; then
	DIGEST=$(sha256sum "$RELEASE_DIR/$ASSET" | awk '{print $1}')
else
	DIGEST=$(shasum -a 256 "$RELEASE_DIR/$ASSET" | awk '{print $1}')
fi
printf '%s  %s\n' "$DIGEST" "$ASSET" >"$RELEASE_DIR/checksums.txt"

PORT_FILE="$TMP/port"
python3 - "$TMP/http" "$PORT_FILE" <<'PY' &
import http.server
import os
import sys

root, port_file = sys.argv[1:]
class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

os.chdir(root)
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), QuietHandler)
with open(port_file, "w", encoding="utf-8") as stream:
    stream.write(str(server.server_address[1]))
server.serve_forever()
PY
SERVER_PID=$!

i=0
while [ ! -s "$PORT_FILE" ]; do
	i=$((i + 1))
	[ "$i" -lt 100 ] || { echo "HTTP fixture failed to start" >&2; exit 1; }
	sleep 0.05
done
BASE_URL="http://127.0.0.1:$(cat "$PORT_FILE")"

run_installer() {
	LLMMAN_BASE_URL="$BASE_URL" LLMMAN_VERSION=test SKIP_INSTALL=1 \
		sh "$ROOT/static/install.sh"
}

expect_failure() {
	name=$1
	if run_installer >"$TMP/$name.out" 2>&1; then
		echo "Expected $name to fail" >&2
		cat "$TMP/$name.out" >&2
		exit 1
	fi
}

run_installer >/dev/null
printf 'ok - matching checksum\n'

MARKER="$TMP/tampered-executed"
cat >"$RELEASE_DIR/$ASSET" <<EOF
#!/bin/sh
touch "$MARKER"
exit 0
EOF
expect_failure tampered
[ ! -e "$MARKER" ] || { echo "Tampered asset was executed" >&2; exit 1; }
printf 'ok - tampered asset is rejected before execution\n'

printf '%s  unrelated-asset\n' "$DIGEST" >"$RELEASE_DIR/checksums.txt"
expect_failure missing
printf 'ok - missing checksum entry\n'

printf 'not-a-sha256  %s\n' "$ASSET" >"$RELEASE_DIR/checksums.txt"
expect_failure malformed
printf 'ok - malformed checksum entry\n'

printf '%s  %s\n%s  %s\n' "$DIGEST" "$ASSET" "$DIGEST" "$ASSET" >"$RELEASE_DIR/checksums.txt"
expect_failure duplicate
printf 'ok - duplicate checksum entries\n'
