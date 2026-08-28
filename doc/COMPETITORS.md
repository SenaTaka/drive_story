# drive_story 競合調査

調査日: 2026-08-28 / 出典は各項の末尾。数字は調査時点の App Store 表示値。

## 結論(先に)

1. **記録(GPSロガー)の土俵では勝てない。勝つ必要もない。** 日本市場は評価数 1,000〜7,000 件規模の先行アプリが埋めており、価格も ¥390/月〜買い切り ¥2,000 と底が抜けている。
2. **「走行データ → そのまま貼れる 1 枚」への変換レイヤーは、日本の車アプリに存在しない。** 調査した国内ドライブ/ツーリング記録アプリはいずれも画像生成機能を持たない。
3. **変換レイヤーの需要は他ジャンルで実証済み。** Relive(2,200万ユーザー)がアクティビティ→動画ストーリーで、Strava が 2025 年春に Stats Stickers で、Polarsteps(1,000万人)が旅程タイムラインで成立させている。**空いているのは「車のドライブ向け」だけ。**
4. **コミュニティ/ルート発見レイヤーは参入が重い。** 国内は CARTUNE(車 SNS 最大級 MAU・全機能無料)が投稿の宛先を押さえている。自前フィードで正面衝突しない。

## レイヤー1: 記録(レッドオーシャン — 入らない)

| アプリ | 評価 | 課金 | 特徴 |
|---|---|---|---|
| ルートヒストリー | ★4.5 / 7,122件 | 買い切り ¥2,000・¥1,100 | GPX 入出力、ログ結合、ルート再生。記録の完全性で勝負 |
| ROADSTOCK | ★4.6 / 1,414件 | ¥100/月・¥700/年 | ツーリング記録+給油/整備/出費。バイク寄り。**画像生成なし** |
| Drive Tracker | ★4.3 / 12件 | ¥390/月・¥890/年・買切¥1,490 | 2026 年の新顔。ヒートマップ・ウィジェット・Siri・CSV |
| DriveHistory / Drive Report | — | — | 走行履歴の可視化・走行距離管理 |

読み: 機能競争に入ると評価数の差で負ける。**記録は「Story を作るための入力」として無料で提供し、売り物にしない。**

## レイヤー2: 変換(ここを取る)

| サービス | 規模 | 何を変換するか | 収益 |
|---|---|---|---|
| Relive | 2,200万ユーザー | GPS 活動 → 3D 動画ストーリー。写真をルート上に自動配置 | Relive Plus(写真100枚・音楽・HD・クレジット除去) |
| Strava Stats Stickers | — | 距離/獲得標高/時間+ルート線画 → IG ストーリー用ステッカー | 本体サブスクの付加価値 |
| Polarsteps | 1,000万人 | 旅程 → 自動タイムライン(経路+写真+統計) | フォトブック印刷 €36〜150 |

読み:
- Relive は**車では機能しない**。3D フライオーバー演出はハイク/ライドの速度域の演出で、100km/2 時間のドライブでは冗長。かつ動画レンダリング待ちが発生する。
- Strava のステッカーは**素材の提供**であって完成品ではない。ユーザーが自分で写真の上に置く。しかも**地名がない**(ルートの線画のみ)。
- → **車ドライブは「どこを走ったか(地名)」が主語**。地名+ルートの形+写真の 3 点が揃った完成品 1 枚は、どこも出していない。

## レイヤー3: コミュニティ/ルート発見(MVP では作らない)

| サービス | 規模/価格 | 読み |
|---|---|---|
| CARTUNE(国内) | 車 SNS 最大級 MAU・全機能無料 | 投稿の宛先は既にここ。競合ではなく**出口**として使う |
| みんカラ(国内) | 老舗。ドライブモード(同時間・同場所の可視化) | 30〜50代中心。若年層は CARTUNE へ移行 |
| RoadStr | 10,000+ ルート・100k+ DL・★4.4 | ルート発見+イベント+クラブ。CarPlay 対応 |
| GarageApp | $50/年 | ルートプランナー+近所のオーナー検索 |
| Rever / Calimoto / Scenic(バイク) | $39.99 / $80 / $48 per year | **この層は年 $40〜80 を払う** — 記録アプリの日本相場より一桁上 |

読み: フィードはユーザー 0 人のとき価値 0。MVP で自前フィードを作らない判断は正しい。**当面の「フィード」は Instagram/TikTok/X 側に置く。**

## 名前の衝突

- 米国 App Store に **"Drive Stories"**(Thomas Moeller / 2025-09 公開 / ★3.3・4件)が既存。中身は走行中に土地の解説を読み上げる**音声観光アプリ**で別カテゴリだが、英語名がほぼ同一。
- 実害は小さい(評価4件)が、英語ストア名は差別化する。表示名の候補は `doc/PRD_MVP.md` §命名 を参照。

## 価格の相場観

- 国内・記録レイヤー: ¥100〜390/月、買い切り ¥1,490〜2,000 → **ここに合わせると事業として死ぬ**
- 海外・ルート/コミュニティ: $40〜80/年
- Relive 型(生成物の質で課金)が最も近い構造

## 出典

- [Relive App Store](https://apps.apple.com/us/app/relive-hike-ride-memories/id1201703657) / [Relive 3D video stories (Silicon Canals)](https://siliconcanals.com/relive-app-3d-video-news/)
- [Strava Stats Stickers (BikeRadar)](https://www.bikeradar.com/news/strava-sticker-stats-spring-2025-updates) / [Strava Community Hub](https://communityhub.strava.com/what-s-new-10/use-strava-stats-stickers-on-ig-stories-ios-android-9344)
- [Polarsteps](https://www.polarsteps.com/) / [Polarsteps × Peecho case study](https://www.peecho.com/case-studies/polarsteps)
- [ルートヒストリー](https://apps.apple.com/jp/app/id1473949280) / [ROADSTOCK](https://apps.apple.com/jp/app/roadstock/id1252969455) / [Drive Tracker](https://apps.apple.com/jp/app/id6754501628)
- [CARTUNE](https://apps.apple.com/jp/app/cartune/id1221199655) / [みんカラ](https://minkara.carview.co.jp/guide/)
- [RoadStr](https://apps.apple.com/gb/app/roadstr-car-routes-events/id1382535778) / [GarageApp](https://garageapp.com/) / [Rever・Calimoto・Scenic 価格(SlashGear)](https://www.slashgear.com/1755865/motorcycle-apps-find-routes-track-rides/)
- [Drive Stories(名前衝突)](https://apps.apple.com/us/app/drive-stories/id6743227880)
