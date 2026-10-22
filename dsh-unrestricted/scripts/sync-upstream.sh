#!/bin/sh
# Sync EXECUTION_MODE_BLOCK from upstream yexi-by/dsh-unrestricted
# into references/delivery-contract.md.
#
# Usage:
#   sh scripts/sync-upstream.sh           fetch upstream, overwrite local contract
#   sh scripts/sync-upstream.sh --check   compare only; exit 0 if equal, 1 if drifted
#
# Requires: curl, sha256sum, and one of perl/awk.
# Override the branch or tag with DSH_REF.

set -eu

REF="${DSH_REF:-master}"
RAW="https://raw.githubusercontent.com/yexi-by/dsh-unrestricted/${REF}/src/rules.js"
SKILL_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET="$SKILL_DIR/references/delivery-contract.md"
FPFILE="$SKILL_DIR/references/upstream-fingerprint.txt"
TMP_DIR="${TMPDIR:-/tmp}/dsh-sync.$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[1/4] fetch $RAW"
curl -fsSL "$RAW" -o "$TMP_DIR/rules.js"

echo "[2/4] extract EXECUTION_MODE_BLOCK"
OUT="$TMP_DIR/contract.md"

if command -v perl >/dev/null 2>&1; then
  perl -0777 -ne '
    if (/EXECUTION_MODE_BLOCK = `(.*?)`\n/s) {
      my $b = $1;
      $b =~ s/\\`/`/g;
      print $b;
    } else {
      print STDERR "FAIL: EXECUTION_MODE_BLOCK not found; upstream layout changed\n";
      exit 3;
    }
  ' "$TMP_DIR/rules.js" > "$OUT"
else
  awk '
    /^export const EXECUTION_MODE_BLOCK = `/ {
      capture = 1
      sub(/^export const EXECUTION_MODE_BLOCK = `/, "")
    }
    capture {
      if (/`$/ && !/^export const/) {
        sub(/`$/, "")
        print
        exit
      }
      print
    }
  ' "$TMP_DIR/rules.js" > "$OUT"
fi

if [ ! -s "$OUT" ]; then
  echo "FAIL: extracted contract is empty" >&2
  exit 3
fi

BYTES=$(wc -c < "$OUT" | tr -d ' ')
NEW_FP=$(sha256sum "$OUT" | cut -c1-16)
echo "      $BYTES bytes, fingerprint $NEW_FP"

OLD_FP="none"
[ -f "$TARGET" ] && OLD_FP=$(sha256sum "$TARGET" | cut -c1-16)
echo "      local fingerprint $OLD_FP"

if [ "$NEW_FP" = "$OLD_FP" ]; then
  echo "[3/4] in sync, nothing to do"
  exit 0
fi

case "${1:-}" in
  --check|-c)
    echo "[3/4] drift detected: upstream changed, re-run without --check to write"
    exit 1
    ;;
esac

echo "[3/4] write $TARGET"
mkdir -p "$SKILL_DIR/references"
cp "$OUT" "$TARGET"
echo "$NEW_FP" > "$FPFILE"
echo "[4/4] done, fingerprint $NEW_FP"
echo "      verify against the upstream settings page contractFingerprint()"
