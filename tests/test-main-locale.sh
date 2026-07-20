#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MAIN="$REPO_ROOT/fnpack/AniRSS/cmd/main"

if ! grep -q '^configure_utf8_locale()' "$MAIN"; then
    echo "FAIL: cmd/main does not configure a UTF-8 process locale before starting Java" >&2
    exit 1
fi

TMP=$(mktemp -d)
cleanup() {
    rm -rf -- "$TMP"
}
trap cleanup EXIT

mkdir -p "$TMP/java/bin" "$TMP/data/logs" "$TMP/pkgvar"
CAPTURE="$TMP/java-env.txt"
UNICODE_FILE="$TMP/data/torrents/N/尼古喵喵/Season 1/test.torrent"

cat > "$TMP/java/bin/java" <<'FAKE_JAVA'
#!/usr/bin/env bash
set -euo pipefail
printf 'LANG=%s\nLC_ALL=%s\n' "${LANG:-}" "${LC_ALL:-}" > "$CAPTURE_FILE"
mkdir -p -- "$(dirname "$UNICODE_TEST_FILE")"
printf 'ok\n' > "$UNICODE_TEST_FILE"
FAKE_JAVA
chmod +x "$TMP/java/bin/java"

LANG=C \
LC_ALL=C \
JAVA_HOME="$TMP/java" \
CAPTURE_FILE="$CAPTURE" \
UNICODE_TEST_FILE="$UNICODE_FILE" \
TRIM_DATA_SHARE_PATHS="$TMP/data" \
TRIM_PKGVAR="$TMP/pkgvar" \
TRIM_TEMP_LOGFILE="$TMP/temp.log" \
run_mode=low \
ui_port=7789 \
proxy_enabled=false \
proxy_host=127.0.0.1 \
proxy_port=7890 \
mcp_enabled=false \
swagger_enabled=false \
bash "$MAIN" start

for _ in $(seq 1 50); do
    [ -f "$CAPTURE" ] && [ -f "$UNICODE_FILE" ] && break
    sleep 0.1
done

[ -f "$CAPTURE" ] || { echo "FAIL: fake Java was not started" >&2; exit 1; }
[ -f "$UNICODE_FILE" ] || { echo "FAIL: Java child could not create a Chinese path" >&2; exit 1; }

grep -Eiq '^LANG=(C\.UTF-8|C\.utf8|en_US\.UTF-8|en_US\.utf8)$' "$CAPTURE" || {
    echo "FAIL: LANG is not UTF-8" >&2
    cat "$CAPTURE" >&2
    exit 1
}
grep -Eiq '^LC_ALL=(C\.UTF-8|C\.utf8|en_US\.UTF-8|en_US\.utf8)$' "$CAPTURE" || {
    echo "FAIL: LC_ALL is not UTF-8" >&2
    cat "$CAPTURE" >&2
    exit 1
}

echo "PASS: Java child starts with a UTF-8 locale and can create a Chinese path"