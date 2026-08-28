#!/bin/zsh
# seed-photos.sh — 写真マッピング検証用の EXIF 付き JPEG を作る。
#
# 全部が「採用されるべき写真」だと、マッチャが素通ししているだけの状態を
# 検出できない。マスク圏内・位置違い・時刻違い・GPS なしを必ず混ぜる。
#
#   scripts/seed-photos.sh [--base "yyyy:MM:dd HH:mm:ss"] [--route hakone-short]
#
# 出力: .verify/photos/*.jpg と .verify/photos/expected.json
# 投入: xcrun simctl addmedia <udid> .verify/photos/*.jpg（verify-drive.sh が行う）
set -eu

cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="$ROOT/.verify/photos"

# 走行の基準時刻。verify-drive.sh は「これから走る」ので、既定は少し未来にする。
BASE=""
ROUTE="hakone-short"
while [ $# -gt 0 ]; do
  case "$1" in
    --base)  BASE="$2"; shift 2 ;;
    --route) ROUTE="$2"; shift 2 ;;
    *) print -u2 "unknown arg: $1"; exit 2 ;;
  esac
done
[ -n "$BASE" ] || BASE="$(date '+%Y:%m:%d %H:%M:%S')"

rm -rf "$OUT"
mkdir -p "$OUT"

# BASE からの経過分を足した "yyyy:MM:dd HH:mm:ss" を返す
at() {
  python3 - "$BASE" "$1" <<'PY'
import sys, datetime
base = datetime.datetime.strptime(sys.argv[1], "%Y:%m:%d %H:%M:%S")
print((base + datetime.timedelta(minutes=float(sys.argv[2]))).strftime("%Y:%m:%d %H:%M:%S"))
PY
}

WP="$ROOT/scripts/waypoints/$ROUTE.txt"
START="$(sed -n '1p' "$WP")"
MID1="$(sed -n '3p' "$WP")"
MID2="$(sed -n '5p' "$WP")"

# START からわずかに離れた点（500m マスク圏内に入る想定）
NEAR_START="$(python3 - "$START" <<'PY'
import sys
lat, lon = map(float, sys.argv[1].split(','))
# 緯度 0.0027 度 ≒ 300m
print(f"{lat + 0.0027:.6f},{lon:.6f}")
PY
)"

make() { # <name> <lat|-> <lon|-> <minutes-offset> <label>
  local name="$1" lat="$2" lon="$3" mins="$4" label="$5"
  swift "$ROOT/scripts/make-exif-photo.swift" "$OUT/$name.jpg" "$lat" "$lon" "$(at "$mins")" "$label" >/dev/null
}

# 走行が始まるのは投入・install・起動を挟んだ 1 分ほど後。走行そのものは 4 分弱。
# 撮影時刻がその窓から外れると全部「時刻レンジ外」で落ち、
# マスクや位置の判定を検証できなくなるので、窓の内側に寄せてある。
make 01 "${NEAR_START%,*}" "${NEAR_START#*,}" 1.5  "01"
make 02 "${MID1%,*}"       "${MID1#*,}"       2.2  "02"
make 03 "${MID2%,*}"       "${MID2#*,}"       3.0  "03"
make 04 "${MID2%,*}"       "${MID2#*,}"       3.4  "04"
make 05 "35.6812"          "139.7671"         2.6  "05"
make 06 "${MID1%,*}"       "${MID1#*,}"       -180 "06"
make 07 "-"                "-"                2.8  "07"

cat > "$OUT/expected.json" <<EOF
{
  "base": "$BASE",
  "route": "$ROUTE",
  "photos": [
    {"name": "01", "expect": "reject", "why": "START から 300m。500m マスク圏内"},
    {"name": "02", "expect": "accept", "why": "走行時刻・走行位置"},
    {"name": "03", "expect": "accept", "why": "走行時刻・走行位置"},
    {"name": "04", "expect": "accept", "why": "走行時刻・走行位置（03 より後）"},
    {"name": "05", "expect": "reject", "why": "東京駅。ルートから遠い"},
    {"name": "06", "expect": "reject", "why": "3 時間前。走行時刻レンジ外"},
    {"name": "07", "expect": "accept", "why": "GPS なし。撮影時刻の補間で救う"}
  ]
}
EOF

print "生成: $OUT"
swift "$ROOT/scripts/read-exif.swift" "$OUT"/*.jpg
