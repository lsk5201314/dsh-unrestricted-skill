#!/bin/sh
# 从上游 yexi-by/dsh-unrestricted 同步 EXECUTION_MODE_BLOCK 到 references/delivery-contract.md
#
# 用法:
#   sh scripts/sync-upstream.sh           抓取上游并覆盖本地契约
#   sh scripts/sync-upstream.sh --check   只比对指纹，不写文件；一致返回 0，不一致返回 1
#
# 依赖: curl, perl, sha256sum

set -eu

REF="${DSH_REF:-master}"
RAW="https://raw.githubusercontent.com/yexi-by/dsh-unrestricted/${REF}/src/rules.js"
SKILL_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET="$SKILL_DIR/references/delivery-contract.md"
FPFILE="$SKILL_DIR/references/upstream-fingerprint.txt"
TMP_DIR="${TMPDIR:-/tmp}/dsh-sync.$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[1/4] 抓取 $RAW"
curl -fsSL "$RAW" -o "$TMP_DIR/rules.js"

echo "[2/4] 提取 EXECUTION_MODE_BLOCK"
perl -0777 -ne '
  if (/EXECUTION_MODE_BLOCK = `(.*?)`\n/s) {
    my $b = $1;
    $b =~ s/\\`/`/g;
    open(my $o, ">", $ARGV . ".block") or die $!;
    print $o $b;
    close $o;
    print "      ok, ", length($b), " bytes\n";
  } else {
    print STDERR "FAIL: 未找到 EXECUTION_MODE_BLOCK，上游结构已变，需人工看 src/rules.js\n";
    exit 3;
  }
' "$TMP_DIR/rules.js"

NEW="$TMP_DIR/rules.js.block"
NEW_FP=$(sha256sum "$NEW" | cut -c1-16)
echo "      上游指纹: $NEW_FP"

OLD_FP="none"
[ -f "$TARGET" ] && OLD_FP=$(sha256sum "$TARGET" | cut -c1-16)
echo "      本地指纹: $OLD_FP"

if [ "$NEW_FP" = "$OLD_FP" ]; then
  echo "[3/4] 一致，无需同步"
  exit 0
fi

case "${1:-}" in
  --check|-c)
    echo "[3/4] 不一致：上游已更新，去掉 --check 即可写回"
    exit 1
    ;;
esac

echo "[3/4] 写入 $TARGET"
mkdir -p "$SKILL_DIR/references"
cp "$NEW" "$TARGET"
echo "$NEW_FP" > "$FPFILE"
echo "[4/4] 完成，新指纹 $NEW_FP（与上游设置页 contractFingerprint 对照）"
