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

- **書き出す画像に地図タイルを焼かない。** タイル画像を SNS に配ると帰属表示・再配布の規約に触れます。
  自前描画なら規約の問題が消え、同時に生活道路や店名が写らないのでプライバシーも解決します。
  一方で**アプリの中で見るだけの画面は MapKit の実地図**を使います。配らないなら制約がないからです。
- **出発・到着の半径 500m を既定で伏せる。** 線の端から自宅が推定できないようにするためです。
  距離と所要時間はマスク前の値を出します。伏せるのは場所であって、走った事実ではありません。
- **記録した事実と絵の材料を分ける。** `DriveRecord` が前者、`DriveStory` が後者で、後者は保存しません。
  混ぜると、写真の選び直しやマスク半径の変更のたびに保存データが壊れます。
- **写真は自動で拾ってから外す。** 全部を手で選ばせると「40 枚をスクロールして選べずに閉じる」に戻ります。
  経路上の位置は**点数比ではなく経路長比**で出します（レンダラがそのパラメータで描いているため）。
  並び順は経路上の位置ではなく撮影時刻です。周回ルートでは位置が前後します。
- **バックグラウンド位置情報は Always を使わない。** 審査コストとバッテリーが割に合いません（前景のみ。Live Activity は未実装）。
- **テンプレごとに画面を作らない。** 1 つのレンダラ + テーマ定義で 4 種を出し分けます。
- **Night / Editorial は写真 0 枚でも成立させる。** 写真が少ない日に生成が破綻しないための保険です。
- **永続化は SwiftData ではなく Codable + JSON。** 座標を含む点列は `@Model` に素直に載らず、
  結局 Codable と同じ手間にマイグレーション責務が乗るだけです（`doc/PRD_MVP.md` §4）。
  差し替えたくなったときのために `protocol DriveRecordStoring` で境界を切ってあります。
- **再生アニメーションは自前ルート描画の上でやり、時間源は外から注入する。**
  `MKMapView` は `ImageRenderer` で焼けないので、地図の上でやると動画化の道が閉じます。
  `TimelineView` を描画 View の内側に置かない限り、同じ描画をフレーム単位で焼いて動画にできます。
- **動画書き出しは MVP に入れない。** アプリの中で再生するところまでです。

## 現況

走って → 終了 → 貼れる 1 枚、までが繋がっています。**走り出しの自動検知**も入りました。
実機での走行はまだ試していません。

| 開発順 | 内容 | 状態 |
|---|---|---|
| ① | Story レンダラ（1080×1920・テンプレ 4 種） | 実装済み |
| ② | 自前ルート描画（簡略化・縦横比保持・写真ピン） | 実装済み |
| ③ | 写真マッピング（撮影時刻・位置と走行ログの照合） | 実装済み |
| ④ | GPS 記録（開始/終了・中断復帰） | 実装済み |
| ⑤ | 逆ジオコーディング + タイトル生成 | 実装済み |
| ⑥ | 編集 UI（写真のトグル + 追加） | 実装済み |
| ⑦ | 共有 + 写真ライブラリへの保存 | 実装済み |
| ⑧ | アプリ内地図（MapKit） | 実装済み |
| ⑨ | 再生アニメーション | 実装済み |
| ⑩ | 走り出しの自動検知（背景で記録） | 実装済み |
| ⑪ | 過去写真モード / 共有 URL | これから |

### シミュレータでの実測（`scripts/verify-drive.sh`、2026-08-29）

18 項目中 16 が PASS。走行〜Story 生成〜アニメまでが画面操作なしで通っています。

| 見たこと | 結果 |
|---|---|
| 自動検知で記録が始まる | **始まった**（`start()` を一度も呼んでいない） |
| 自動検知で記録が締まる | **締まった**（停止窓を満たして自動終了） |
| 記録点数 / 距離 | 143 点 / **5.21 km**（期待 5.39 km・誤差 3.4%） |
| 500m マスク | 始点 **535m** / 終点 **517m** 除去 |
| ルートの形 | 14 点（簡略化で潰れていない） |
| 地名 | 逆ジオコーディングで **「Hakone」** |
| Story 4 枚 | 4 テンプレとも 1080×1920・多色 |
| 再生アニメ | 24 コマ・進捗 0.00 → 1.00 単調増加 |

**未達 2 件（いずれも写真ライブラリの権限）**: シミュレータでは `simctl privacy grant photos` が
効かず（iOS 26.0 / 18.6 の両方で `notDetermined`。TCC を直接書いても変わらず）、
実 `PHAsset` の読み出しと写真ライブラリへの保存だけ検証できていません。
突き合わせの判定そのものは `PhotoCandidate` 経由で権限なしに検証できるようにしてあります
（マスク圏内 / ルートから遠い / 時刻レンジ外 / 位置なし を必ず混ぜる）。
**実 PHAsset の受け渡しと保存は実機で人が確認する必要があります。**

## 実装計画（MVP）

**ゴールは「シミュレータで、走って → 終了 → 貼れる 1 枚ができる」まで通すこと。** 実機検証は後回しにします。

### 記録レイヤーは car_ui から移植する

同じワークスペースの `../car_ui`（App Store 公開済みの OBD2 車両データアプリ）に、実運用を通った GPS 記録・軌跡永続化・地図描画があります。その大半は OBD/BLE 層に結合していないので、ゼロから書かずに持ってきます。

| 移植元 | 行数 | 扱い |
|---|---|---|
| `LocationModel.swift` | 160 | コピーして 7 行削る。`kCLLocationAccuracyBestForNavigation` / `activityType = .automotiveNavigation` / 精度フィルタ（距離加算は精度 50m 未満かつ移動 1m 超、軌跡は 100m 未満）/ `GPSQuality` をそのまま使う |
| `TrackStore.swift` | 157 | 構造だけ流用。1Hz 間引き + Application Support への atomic JSON write は有用。ただし car_ui は「単一の連続軌跡」なのでセッション単位に作り替える |
| `DriveSession.swift` | 62 | ほぼそのまま。経過時間の H:MM:SS 整形は完成品 |
| `TrackMapPanel.swift` | 781 | 一部のみ。`MapPolyline` の描画と「60 秒の時間ギャップで線を切る」考え方。781 行を丸ごと持ち込まない |
| `Units.swift` | 268 | 移植しない。MVP は km 固定（imperial 対応は MVP の要件にない） |

car_ui に無くこちらに既にあるもの: 自前の緯度経度投影と Douglas-Peucker（`RouteOutline`）、ImageRenderer での書き出し（`StoryExporter`）。car_ui にも無く新規に書くもの: 写真ライブラリ、セッション単位の永続化、再生アニメーション。

### 実装順序

ステップ 1〜6 で「シミュレータで一連が動く」に到達します。7 以降は上積みです。

| # | やること | 完了条件 | 実装 |
|---|---|---|---|
| 1 | `StoryPreviewScreen` の入力化（`init(story:)` 化、`RootView` 新設） | サンプルの表示とテンプレ切替が今までどおり動く（退行なし） | 済 |
| 2 | 記録層の移植（`RoutePoint` / `LocationTracker` / `DriveRecorder` / `RecordScreen`） | 擬似 GPS を流して経過時間と距離が増える | 済 |
| 3 | 永続化 + 履歴（`DriveRecord` / `DriveRecordStore` / 記録中の退避） | 終了 → アプリを kill → 再起動で履歴に 1 件残る。記録中に kill しても復帰する | 済 |
| 4 | マスク + Outline 接続 + `StoryBuilder`（写真なし版） | 終了直後に Story プレビューが**実走行の形**で開く。始点 500m が線から消えている | 済 |
| 5 | 写真マッピング（`PhotoLibraryService` / `PhotoMatcher` / `PhotoImageCache`） | 走行時刻レンジの写真を投入すると写真枠に実写が出て、ピンが経路上に載る | 済 |
| 6 | 共有 + 保存（`ShareSheet`） | 共有シートが開き、1080×1920 の PNG が写真ライブラリに入る。**ここで骨格が通る** | 済 |
| 7 | 写真の編集 UI（トグル + PHPicker 追加） | チェックを外すとピンと写真が消え、再起動後も維持される | 済 |
| 8 | 逆ジオコーディング + タイトル生成 | タイトルが実地名になり、オフライン時もフォールバックして落ちない | 済 |
| 9 | アプリ内地図（`DriveMapScreen`） | 実地図に軌跡と写真ピンが出て、ギャップ区間で線が切れている | 済 |
| 10 | 再生アニメーション | ルートが伸びて写真が撮影時刻順に出る | 済 |

「実装」列はコードが入ってビルドが通ったという意味です。**完了条件を満たしたかの確認はこれから**で、
`scripts/verify-drive.sh` が中断したままになっています（下記「シミュレータでの検証」）。

## 構成

記録した事実（`DriveRecord`）と、絵の材料（`DriveStory`）を分けています。
後者は保存せず、`StoryBuilder` が毎回組み立て直す使い捨ての構造体です。
ここを混ぜると、写真の選び直しやマスク半径の変更のたびに保存データが壊れます。

```
DriveStory/
  Record/     RoutePoint          走行軌跡の 1 点（記録用の生データ）
              LocationTracker     CLLocationManager。精度フィルタと GPS 品質だけを持つ
              DriveRecorder       走行 1 回の記録。1Hz 間引き・中断時の退避と復元
              RouteMask           出発・到着の半径 500m を落とす
  Store/      DriveRecord         走行の事実。永続する唯一の単位
              DriveRecordStore    Application Support の JSON。履歴 100 件まで
  Photos/     PhotoRef            Story に載せる候補 1 枚（実画像は持たない）
              PhotoLibraryService PhotoKit への唯一の窓口
              PhotoMatcher        走行時刻・位置と写真の突き合わせ
              PhotoImageCache     焼く前に実画像を揃えるための層
              PhotoSaver          完成した 1 枚を写真ライブラリへ
  Compose/    StoryBuilder        DriveRecord → DriveStory。記録層と描画層の唯一の接点
              PlaceNamer          マスク後の点を逆ジオコーディングして地名を決める
  Model/      DriveStory          Story 1 枚分の材料（描画用に畳んだもの）
  Render/     RouteOutline        緯度経度 → Douglas-Peucker → 縦横比を保って単位正方形へ
              RouteShape          ルートの描画。START/GOAL と写真ピンを経路上に置く
              StoryTheme          4 テンプレの配色とタイポ
              StoryExporter       ImageRenderer で 1080×1920 の PNG に焼く
  Templates/  StoryCanvas         4 テンプレのレイアウト
              StoryParts          共通部品（統計・タグ・星・CTA・写真枠）
  Playback/   StoryPlayback       時間 → コマ（純関数）と、ルートが伸びる描画層
  Screens/    RootView            画面遷移とデバッグ経路の集約点
              RecordScreen        ホーム。走行の開始・終了と履歴
              StoryPreviewScreen  最重要画面。編集・地図・再生・共有のハブ
              PhotoSelectScreen   自動で拾った写真を外す
              DriveMapScreen      アプリ内の実地図（MapKit）
              StoryPlaybackScreen 再生
              ShareSheet          標準の共有シート
  Verify/     VerifyHarness       DRIVE_VERIFY=1 の通し実行（UI をバイパスする）
  Sample/     SampleDrives        レンダラ検証用のダミー走行データ
doc/      COMPETITORS.md（競合調査）/ PRD_MVP.md（MVP 要件）
store/    VALUE_SHEET.md（価値訴求シート・仮説）
vision/   テンプレ 4 種の決定稿ビジュアル
scripts/  verify-drive.sh（通し検証）/ seed-photos.sh / make-exif-photo.swift
          read-exif.swift / waypoints/（擬似 GPS のルート）
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

## シミュレータでの検証

ビルドが通っても画像が崩れていることはあります（実際に、gradient の高さ指定だけ古い値が残って
上端に 220px の黒帯が出たことがあり、ビルドは成功したままでした）。**成果物を吐かせて目で見る**のが唯一の検出手段です。

### 絵だけ確認する

`STORY_DUMP=1` を渡して起動すると、全テンプレ × 全サンプルの PNG を Documents に書き出します。

```sh
SIMCTL_CHILD_STORY_DUMP=1 xcrun simctl launch <device-id> com.senatakasawa.drivestory
open "$(xcrun simctl get_app_container <device-id> com.senatakasawa.drivestory data)/Documents"
```

### 一連の流れを通しで確認する

`scripts/verify-drive.sh` が、専用シミュレータの作成から擬似走行・写真投入・成果物の回収までを通しで回します。

- **擬似 GPS**: `xcrun simctl location <udid> start --speed=<m/s> --distance=<m> -` にウェイポイントを流します（`scripts/waypoints/`）。**launch 前に `location set` で START に置く**こと — 既定の Cupertino のままだと 1 点目が太平洋を跨いで距離が壊れます。
- **EXIF 付きサンプル写真**: このマシンには exiftool も Pillow もなく、`sips` は EXIF を扱えません。`scripts/make-exif-photo.swift`（Swift + ImageIO）で撮影時刻と GPS を書いた JPEG を作り、`xcrun simctl addmedia` で投入します。`OffsetTimeOriginal` を必ず入れてください（無いとタイムゾーン解釈が端末依存になり、時刻レンジ一致が静かにずれます）。**マスク圏内・位置違い・時刻違い・GPS なしを混ぜた 7 枚**を投入します。全部通ると「マッチャが素通ししているだけ」を検出できません。
- **権限**: `xcrun simctl privacy <udid> grant location|photos|photos-add <bundle>` を、**install の後・アプリを一度も起動しないうちに**実行します。install より前だと効きません（TCC のエントリが install で流れます）。一度でも位置プロンプトを出した端末では iOS 26 で grant が効かなくなるので、専用シミュレータを毎回作って捨てます。
- **シミュレータは 2 回 boot する**: `simctl create` 直後の端末は写真まわりのサービスが立ち上がっておらず、`addmedia` が `LaunchdSimError 133` で落ちるか、**無出力でハングします**。一度 `shutdown` して boot し直すと通ります。
- **タップ不要**: `DRIVE_VERIFY=1` で起動すると、記録開始 → 走行 → 終了 → 写真マッピング → Story 生成までを画面操作なしで実行し、`Documents/verify/<runid>/` に走行 JSON・写真の採否理由・Story 4 枚・アニメのフレーム連番を書き出します。**ハーネスは UI 層だけをバイパスし、本番と同じサービス層を呼びます** — ハーネス専用のロジックを書いた瞬間、この検証は何も担保しなくなります。

回収したら **Story 4 枚とアニメのコンタクトシートは必ず開いて見てください。** 機械判定の pass は「真っ黒/白紙ではない」ことしか保証しません。

### この経路で検証できないもの

権限ダイアログの文言と初回体験 / ボタンのタップ反応と共有シート / アニメーションの質感 / 実 GPS の精度とトンネル欠測 / HEIC・Live Photo・iCloud 未ダウンロードの実カメラロール。これらは実機で人間が確認します。

## ライセンス

未定。
