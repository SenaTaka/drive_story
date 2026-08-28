# Drive Story

ドライブの走行ログと写真から、**そのまま SNS に貼れる 9:16 の 1 枚**を自動生成する iOS アプリ。

大学のプロジェクトです。全機能無料で、課金・サブスクリプション・広告は実装しません。

---

## 何を作るのか

走り終わって「終了」を押すと、ルートの形・地名・距離・所要時間・写真が入った 1080×1920 の画像ができます。
下は実際にレンダラが書き出したもの（走行データはサンプル）。

| Scenic | Route | Editorial | Night |
|---|---|---|---|
| <img src="doc/samples/hakone-morning-drive_scenic.png" width="200"> | <img src="doc/samples/chirihama-coastal-drive_route.png" width="200"> | <img src="doc/samples/venus-line_editorial.png" width="200"> | <img src="doc/samples/tokyo-night-loop_night.png" width="200"> |
| 実写が主役 | ルートが主役 | 雑誌組版 | 黒×赤・写真 0 枚でも成立 |

## 記録アプリではなく、変換アプリ

GPS ロガーは既に成熟していて、機能競争に入る意味がありません（`doc/COMPETITORS.md`）。
一方、走行データを「そのまま貼れる 1 枚」に変換する部分は、車のドライブ向けにはどこも作っていません。
Relive（アクティビティ → 動画）や Strava の Stats Stickers は隣接しますが、前者は自転車・ランの速度域の演出で、
後者はルートの線画だけで**地名がありません**。車のドライブは「どこを走ったか」が主語です。

このアプリで一番大事な画面は、ホームでも記録中でもなく、**走り終わった直後の Story プレビュー**です。

## 設計上の決定

- **地図タイルを使わず、ルートを自前で描く。** タイル画像を焼いて SNS に配ると帰属表示・再配布の規約に触れます。
  自前描画なら規約の問題が消え、同時に生活道路や店名が写らないのでプライバシーも解決します。
- **出発・到着の半径 500m を既定で伏せる。** 線の端から自宅が推定できないようにするためです。
- **バックグラウンド位置情報は Always を使わない。** When In Use + Live Activity で足ります。
- **テンプレごとに画面を作らない。** 1 つのレンダラ + テーマ定義で 4 種を出し分けます。
- **Night / Editorial は写真 0 枚でも成立させる。** 写真が少ない日に生成が破綻しないための保険です。

## 現況

企画とレンダラまで。GPS 記録・写真マッピングはこれから。

| 開発順 | 内容 | 状態 |
|---|---|---|
| ① | Story レンダラ（1080×1920・テンプレ 4 種） | 実装済み |
| ② | 自前ルート描画（簡略化・縦横比保持・写真ピン） | 実装済み |
| ③ | 写真マッピング（撮影時刻・位置と走行ログの照合） | これから |
| ④ | GPS 記録（開始/終了・Live Activity） | これから |
| ⑤〜⑨ | 逆ジオコーディング / 編集 UI / 共有 / 過去写真モード / 共有 URL | これから |

①②はドライブを 1 回もせずに実装・検証できるので、先に絵を確定させています。

## 構成

```
DriveStory/
  Model/DriveStory.swift        Story 1 枚分の材料（走行ログ本体ではなく描画用に畳んだもの）
  Render/RouteOutline.swift     緯度経度 → Douglas-Peucker で簡略化 → 縦横比を保って単位正方形へ
  Render/RouteShape.swift       ルートの描画。START/GOAL と写真ピンを経路上の位置に置く
  Render/StoryTheme.swift       4 テンプレの配色とタイポの定義
  Render/StoryExporter.swift    ImageRenderer で 1080×1920 の PNG に焼く
  Templates/StoryCanvas.swift   4 テンプレのレイアウト
  Templates/StoryParts.swift    共通部品（統計・タグ・星・CTA）
  Screens/StoryPreviewScreen.swift  最重要画面
  Sample/SampleDrives.swift     検証用のダミー走行データ
doc/     COMPETITORS.md（競合調査）/ PRD_MVP.md（MVP 要件）
store/   VALUE_SHEET.md（価値訴求シート・仮説）
vision/  テンプレ 4 種の決定稿ビジュアル
```

## ビルド

XcodeGen 管理です。`.xcodeproj` を直接編集せず、`project.yml` を変えて再生成してください。

```sh
xcodegen generate
open DriveStory.xcodeproj
```

コマンドラインでコンパイルだけ確認する場合:

```sh
xcodebuild -project DriveStory.xcodeproj -scheme DriveStory \
  -destination 'generic/platform=iOS Simulator' build
```

要件: Xcode 16 以降 / iOS 17.0 以降 / XcodeGen 2.45 以降

## レンダリング結果の確認

ビルドが通っても画像が崩れていることはあります（実際に、gradient の高さ指定だけ古い値が残って
上端に 220px の黒帯が出たことがあり、ビルドは成功したままでした）。
`STORY_DUMP=1` を渡して起動すると、全テンプレ × 全サンプルの PNG を Documents に書き出します。

```sh
SIMCTL_CHILD_STORY_DUMP=1 xcrun simctl launch <device-id> com.senatakasawa.drivestory
open "$(xcrun simctl get_app_container <device-id> com.senatakasawa.drivestory data)/Documents"
```

## ライセンス

未定。
