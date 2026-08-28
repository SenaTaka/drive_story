#!/bin/zsh
# verify-drive.sh — 走行〜Story 生成をシミュレータで通しで検証する。
#
# 画面をタップせずに検証する。理由は 2 つ:
#   - エージェントにはシミュレータのタップ権限が無い（~/ios/_AI_AGENT_NOTES/simulator-device.md 2026-08-26）
#   - 「ビルド成功」では絵の崩れが検出できない（done.md 2026-08-28 の黒帯）
# アプリ側の DRIVE_VERIFY=1 が UI をバイパスして本番と同じサービス層を叩き、
# 成果物を Documents/verify/<runid>/ に吐く。それを回収して機械判定 + 目視する。
#
# 使い方:
#   scripts/verify-drive.sh [--route hakone-short|hakone-loop] [--speed 20]
#                           [--runtime 26.0|26.3|18.6] [--device "iPhone 16 Pro"]
#                           [--no-photos] [--keep]
#
# xcb で包んで呼ぶこと（ビルドロック）:
#   ~/ios/bin/xcb zsh scripts/verify-drive.sh
set -eu

cd "$(dirname "$0")/.."
ROOT="$PWD"
BUNDLE="com.senatakasawa.drivestory"

ROUTE="hakone-short"
SPEED=20
RUNTIME="26.0"
DEVICE="iPhone 16 Pro"
KEEP=0
PHOTOS=1

while [ $# -gt 0 ]; do
  case "$1" in
    --route)   ROUTE="$2"; shift 2 ;;
    --speed)   SPEED="$2"; shift 2 ;;
    --runtime) RUNTIME="$2"; shift 2 ;;
    --device)  DEVICE="$2"; shift 2 ;;
    --keep)      KEEP=1; shift ;;
    --no-photos) PHOTOS=0; shift ;;
    *) print -u2 "unknown arg: $1"; exit 2 ;;
  esac
done

WAYPOINTS="$ROOT/scripts/waypoints/$ROUTE.txt"
[ -f "$WAYPOINTS" ] || { print -u2 "no such route: $WAYPOINTS"; exit 2 }

# --- 前提チェック -----------------------------------------------------------
for tool in xcodegen xcrun python3; do
  command -v "$tool" >/dev/null || { print -u2 "missing: $tool"; exit 2 }
done

RUNID="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/.verify/$RUNID"
mkdir -p "$OUT"

# 期待距離はウェイポイントから実測する（手で書いた値は必ずずれる）
EXPECT_KM=$(python3 - "$WAYPOINTS" <<'PY'
import math, sys
def hav(a, b):
    R = 6371000
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dp, dl = p2 - p1, math.radians(b[1] - a[1])
    h = math.sin(dp/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return 2 * R * math.asin(math.sqrt(h))
pts = [tuple(map(float, l.split(','))) for l in open(sys.argv[1]) if l.strip()]
print(f"{sum(hav(pts[i], pts[i+1]) for i in range(len(pts)-1))/1000:.3f}")
PY
)
START="$(head -1 "$WAYPOINTS")"

UDID=""
cleanup() {
  [ -n "$UDID" ] || return 0
  if [ "$KEEP" -eq 1 ]; then
    print "シミュレータを残した: $UDID"
    return 0
  fi
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  # 使い捨てにする。位置プロンプトを一度出した端末では grant が効かなくなるため
  # （~/ios/_AI_AGENT_NOTES/simulator-device.md 2026-08-17）。
  xcrun simctl delete "$UDID" >/dev/null 2>&1 || true
  "$HOME/ios/bin/simc" off >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

step() { print "\n[$1] $2" }

# --- 1. ビルド --------------------------------------------------------------
step 1 "xcodegen + build"
xcodegen generate >/dev/null
xcodebuild -project DriveStory.xcodeproj -scheme DriveStory \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath .build build >"$OUT/build.log" 2>&1 \
  || { print -u2 "build failed → $OUT/build.log"; tail -30 "$OUT/build.log" >&2; exit 1 }
APP=$(find .build/Build/Products -name 'DriveStory.app' -maxdepth 3 | head -1)
[ -n "$APP" ] || { print -u2 "DriveStory.app が見つからない"; exit 1 }

# --- 2. 専用シミュレータ ----------------------------------------------------
step 2 "シミュレータを作る（使い捨て）"
UDID=$(xcrun simctl create "DriveStory-Verify-$RUNID" "$DEVICE" \
       "com.apple.CoreSimulator.SimRuntime.iOS-${RUNTIME//./-}")
# bootstatus は無出力で 15 分ハングした実績があるので使わない（NOTES 2026-08-19）。
wait_boot() {
  for _ in {1..90}; do
    xcrun simctl spawn "$UDID" launchctl print system >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

xcrun simctl boot "$UDID"
wait_boot || { print -u2 "boot しない"; exit 1 }

# 2026-08-28 実測: 作りたての端末では写真まわりのサービスが立ち上がっておらず、
# simctl addmedia が LaunchdSimError 133 で落ちる（ハングすることもある）。
# 一度 shutdown して boot し直すと通る。初回 boot のセットアップを終わらせるため。
xcrun simctl shutdown "$UDID"
sleep 3
xcrun simctl boot "$UDID"
wait_boot || { print -u2 "再 boot しない"; exit 1 }
sleep 8

# --- 3. install -------------------------------------------------------------
step 3 "install"
xcrun simctl install "$UDID" "$APP"

# --- 4. 権限（install の後・初回起動の前）-----------------------------------
#
# 2026-08-28 実測: install より前に grant すると、iOS 26 では起動時に
# 位置情報ダイアログがそのまま出る（TCC のエントリが install で失われる）。
# 「アプリを一度も起動しないうちに」に加えて「install の後で」が要る。
step 4 "権限を与える（install 後・初回起動前）"
xcrun simctl privacy "$UDID" grant location   "$BUNDLE"
xcrun simctl privacy "$UDID" grant photos     "$BUNDLE" 2>/dev/null || true
xcrun simctl privacy "$UDID" grant photos-add "$BUNDLE" 2>/dev/null || true

# --- 5. 写真の投入 + START に置く -------------------------------------------
#
# 写真は「ここで」作る。走行の直前に作らないと、撮影時刻が走行時刻レンジから外れて
# 全部 reject され、マッチャが壊れているのか写真がずれているのか区別できなくなる。
if [ "$PHOTOS" -eq 1 ]; then
  step 5 "EXIF 付き写真を作って投入し、START に置く"
  zsh "$ROOT/scripts/seed-photos.sh" --route "$ROUTE" >"$OUT/seed-photos.log" 2>&1 \
    || { print -u2 "写真の生成に失敗 → $OUT/seed-photos.log"; tail -20 "$OUT/seed-photos.log" >&2; exit 1 }
  # 再 boot 済みなら通るはずだが、念のため 1 枚ずつリトライする。
  for photo in "$ROOT"/.verify/photos/*.jpg; do
    added=0
    for _ in {1..5}; do
      if xcrun simctl addmedia "$UDID" "$photo" >/dev/null 2>&1; then added=1; break; fi
      sleep 3
    done
    [ "$added" -eq 1 ] || { print -u2 "addmedia が通らない: $photo"; exit 1 }
  done
  cp "$ROOT/.verify/photos/expected.json" "$OUT/20_photos_expected.json" 2>/dev/null || true
else
  step 5 "写真なし（--no-photos）。START に置く"
fi
# 既定の Cupertino のままだと 1 点目が太平洋を跨いで距離が壊れる。
xcrun simctl location "$UDID" set "$START"

# --- 6. launch（DRIVE_VERIFY）----------------------------------------------
step 6 "DRIVE_VERIFY=1 で起動"
SIMCTL_CHILD_DRIVE_VERIFY=1 \
SIMCTL_CHILD_DRIVE_VERIFY_RUNID="$RUNID" \
SIMCTL_CHILD_DRIVE_VERIFY_EXPECT_KM="$EXPECT_KM" \
xcrun simctl launch --console-pty "$UDID" "$BUNDLE" >"$OUT/console.log" 2>&1 &
LAUNCH_PID=$!

DATA=""
for _ in {1..60}; do
  DATA=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data 2>/dev/null || true)
  [ -n "$DATA" ] && [ -f "$DATA/Documents/verify/$RUNID/01_started" ] && break
  sleep 1
done
[ -n "$DATA" ] && [ -f "$DATA/Documents/verify/$RUNID/01_started" ] \
  || { print -u2 "記録が始まらない → $OUT/console.log"; tail -30 "$OUT/console.log" >&2; exit 1 }

# --- 7. 擬似 GPS ------------------------------------------------------------
step 7 "擬似 GPS を流す（$ROUTE / ${SPEED}m\\s / 期待 ${EXPECT_KM}km）"
xcrun simctl location "$UDID" start --speed="$SPEED" --distance=20 - <"$WAYPOINTS"

# --- 8. 完了待ち ------------------------------------------------------------
step 8 "完了待ち"
DEADLINE=$(( $(date +%s) + 2400 ))
while [ ! -f "$DATA/Documents/verify/$RUNID/99_done" ]; do
  [ $(date +%s) -gt $DEADLINE ] && { print -u2 "タイムアウト"; tail -30 "$OUT/console.log" >&2; exit 1 }
  sleep 3
done

# --- 9. 回収 ----------------------------------------------------------------
step 9 "成果物を回収"
cp -R "$DATA/Documents/verify/$RUNID/." "$OUT/" 2>/dev/null || true
kill "$LAUNCH_PID" 2>/dev/null || true

print "\n--- 90_result.json ---"
python3 - "$OUT/90_result.json" <<'PY'
import json, sys
try:
    r = json.load(open(sys.argv[1]))
except Exception as e:
    print("読めない:", e); raise SystemExit(1)
for a in r["assertions"]:
    print(("PASS " if a["pass"] else "FAIL ") + f'{a["name"]}: {a["actual"]} (期待 {a["expected"]})')
print("overallPass:", r["overallPass"])
raise SystemExit(0 if r["overallPass"] else 1)
PY
RESULT=$?

print "\n結果: $OUT"
ls "$OUT"
print "\n目視必須: $OUT の 40_*.png と anim_contact.png（機械判定は真っ黒/白紙しか捕まえない）"
exit $RESULT
