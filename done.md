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
