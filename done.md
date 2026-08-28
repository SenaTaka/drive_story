# drive_story 作業ログ

## 2026/08/28 15:30
- 企画開始。ユーザー提示の「Drive Story Generator」要件に競合調査を当てて MVP を確定。
- 競合調査 `doc/COMPETITORS.md`: 記録レイヤー(ルートヒストリー★4.5/7,122件・ROADSTOCK★4.6/1,414件・Drive Tracker)は
  価格が底(¥390/月〜買切¥1,490)で参入不可。変換レイヤー(Relive 2,200万人・Strava Stats Stickers・Polarsteps 1,000万人)は
  他ジャンルで実証済みだが**車ドライブ向けは空白**。国内の車アプリに画像生成機能なし。
- 元案から変えた 6 点は `doc/PRD_MVP.md` §0。最大の変更は (a) MVP の目的をループから「共有までの摩擦ゼロ」へ
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
