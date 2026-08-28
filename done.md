# drive_story 作業ログ

## 2026/08/28 15:30
- 企画開始。ユーザー提示の「Drive Story Generator」要件に競合調査を当てて MVP を確定。
- 競合調査 `doc/COMPETITORS.md`: 記録レイヤー(ルートヒストリー★4.5/7,122件・ROADSTOCK★4.6/1,414件・Drive Tracker)は
  機能を出し尽くしていて入る余地がない。変換レイヤー(Relive 2,200万人・Strava Stats Stickers・Polarsteps 1,000万人)は
  他ジャンルで実証済みだが**車ドライブ向けは空白**。国内の車アプリに画像生成機能なし。
- 大学のプロジェクトのため**全機能無料・課金なし**を前提に確定(2026-08-28 ユーザー指示)。
- 元案から変えた 5 点は `doc/PRD_MVP.md` §0。最大の変更は (a) MVP の目的をループから「共有までの摩擦ゼロ」へ
  (b) Save Drive / Drive this route を Must から外す (c) 過去写真モードを追加して TTFV を短縮。
- 価値訴求シート `store/VALUE_SHEET.md` を仮説で起票(VoC 未収集)。
- Xcode プロジェクト新設(XcodeGen 2.46.0 / bundle id `com.senatakasawa.drivestory` / iOS 17.0 / Portrait のみ)。
- 開発順①② を実装: Story レンダラ(1080×1920)+ 自前ルート描画(Douglas-Peucker 簡略化・縦横比保持・写真ピン)。
  テンプレ 4 種(scenic / route / editorial / night)を 1 レンダラ + テーマで実装。
- 検証: `SIMCTL_CHILD_STORY_DUMP=1` で 16 枚の PNG を Documents へ書き出し、目視で確認。
  4 回作り直した(ダミールートが GPS ノイズ状の棘になっていた / scenic の CTA が枠外 /
  editorial のタイトル切れと CTA 色誤り / night のルートが数字に重なる)。最終的に 4 テンプレとも破綻なし。
- ハマった点: LinearGradient の `.frame(height:)` だけ旧値(1120)が残り、ZStack が 1120 になって
  bottomLeading で写真が下に寄り、上に 220px の黒帯が出た。**ビルド成功では検出できない**。目視で発見。

## 2026/08/28 18:15
- MVP の実装計画を README に記載（`404efe2`）。この会話を見ていない人（共同開発の 2 人・後日の自分）が読む場所は repo という判断。
- 記録層は **`../car_ui`（公開済み OBD2 アプリ）から移植**する方針を確定。調査した結果、`LocationModel`(160行) / `TrackStore`(157行) / `DriveSession`(62行) は OBD 依存がほぼ無く、削る行まで特定済み（README の表）。`Units.swift` は MVP では移植しない（km 固定）。
- 確定した設計判断: ①アプリ内は MapKit の実地図・書き出しは自前ルート線 ②動画は MVP 外（アプリ内再生アニメまで。ただし `TimelineView` を描画 View の内側に入れないことで mp4 化の道を残す）③写真は自動抽出＋トグルで外す ④永続化は SwiftData ではなく Codable + JSON（PRD §4 に追記）
- 検証は **タップ不要の `DRIVE_VERIFY=1` 経路**で組む。サブエージェントはシミュレータのタップができない（NOTES 2026-08-26）ため、UI をバイパスして成果物を Documents に吐かせる形にする。
- **EXIF 付きサンプル写真の生成手段を実地確認**: このマシンには exiftool も Pillow も piexif も無く `sips` は EXIF を扱えない → **Swift + ImageIO** で DateTimeOriginal と GPS を書いて読み戻せることを確認済み。
- `CLAUDE.md` の「現況」が「Xcode プロジェクト未作成」のままで README・done.md と矛盾していたので実態に修正。

## 2026/08/28 20:05
- MVP のステップ 1〜10 を実装。`../car_ui` から記録層を移植（`LocationModel`→`LocationTracker`、`TrackStore`+`DriveSession`→`DriveRecorder`）。
- 新設: `Record/`（RoutePoint・LocationTracker・DriveRecorder・RouteMask）/ `Store/`（DriveRecord・DriveRecordStore）/ `Photos/`（PhotoRef・PhotoLibraryService・PhotoMatcher・PhotoImageCache・PhotoSaver）/ `Compose/`（StoryBuilder・PlaceNamer）/ `Playback/`（StoryPlayback）/ `Screens/`（RootView・RecordScreen・PhotoSelectScreen・DriveMapScreen・StoryPlaybackScreen・ShareSheet）/ `Verify/`（VerifyHarness）。
- 検証は **タップ不要の `DRIVE_VERIFY=1` 経路**。`scripts/verify-drive.sh` が専用シミュレータ作成→写真投入→擬似 GPS→成果物回収まで通す。EXIF 付き写真は `scripts/make-exif-photo.swift`（Swift + ImageIO。このマシンには exiftool も Pillow も無い）。
- **未完了**: 通し検証が中断のまま。ビルドと画面表示は確認済みだが、走行〜Story 生成の一連が通った証拠（`90_result.json` と 4 枚の目視）はまだ無い。再開は `~/ios/bin/xcb zsh scripts/verify-drive.sh`。
- ハマった点 3 つ（いずれも NOTES/スクリプトに反映済み）:
  - `simctl privacy grant` は **install の後**でないと効かない。前に打つと初回起動で位置ダイアログが出る。
  - ハーネスが擬似 GPS の開始前に「走行終了」と誤判定して 1 点で終わる → 最低点数と開始猶予のガードを追加。
  - **`simctl create` 直後の端末は `addmedia` が通らない**（133 で落ちるか無出力ハング）。**shutdown→再 boot の 2 回 boot** で通る。

## 2026/08/29 07:30
- **走り出しの自動検知**を追加（`DriveDetector`）。Core Motion `.automotive` と GPS 速度の持続の 2 系統。既定オフで、オンのときだけ Always 権限 + Background Modes(location)。PRD/CLAUDE.md の「Always を使わない」方針をユーザー指示で変更し、理由つきで両方に記録。
- **シミュレータで 18 項目中 16 が PASS**。自動検知での開始・終了、距離 5.21km（期待 5.39km）、マスク 535m/517m、地名「Hakone」、Story 4 枚、アニメ 24 コマ。
- 検証でつまずいた点（すべて修正済み・NOTES にも反映）:
  - `simctl location start` はルート走破後も同じ座標を送り続ける → 点数ベースの終了判定は永久に成立しない。**距離ベース**に変更。`DriveDetector` も速度の申告を信じず**変位**で止まったと判断する（実機でも速度が張り付く場面があるので堅牢性になる）。
  - `--reuse` を足したとき install まで飛ばしていて、**古いバイナリで検証していた**。飛ばすのは create と 2 回 boot だけにした。
  - `--console-pty` で起動するとアプリが launch プロセスの子になり、スクリプトが止まると**アプリごと落ちて成果物が書かれない**。素の launch に変更。
  - Douglas-Peucker の許容誤差が絶対値固定で、4.7km の街乗りが **3 点に潰れた**。経路の広がりに対する比にし、長距離は従来値を上限にして決定稿ビジュアルを保った。
  - `PHImageManager.requestImage` を「完成版だけ受け取る」で待っていて、完成版が来ないと**永久に待つ**形だった。速報を保持して必ず返すように。
  - **`simctl privacy grant photos` が iOS 26.0 でも 18.6 でも効かない**（notDetermined のまま。TCC 直書きでも変わらず）。`PhotoMatcher` を `PHAsset` から `PhotoCandidate` に切り離し、判定そのものは権限なしで検証できるようにした。
- **未達**: 実 PHAsset の読み出しと写真ライブラリ保存は実機でのみ検証可能。合成候補での判定検証は実装済みだが、シミュレータ基盤が不安定になり（`simctl` が応答停止）実行までは至っていない。
