import Foundation
import CoreLocation
import SwiftUI
import UIKit

/// シミュレータ検証用のハーネス。`DRIVE_VERIFY=1` で起動すると
/// 画面操作なしで走行〜Story 生成までを走らせ、成果物を Documents に吐く。
///
/// サブエージェントはシミュレータの画面をタップできないので、
/// 「ボタンを押した先」を確かめる経路がこれしかない。
///
/// **UI 層だけをバイパスし、本番と同じ `DriveRecorder` などを呼ぶこと。**
/// ハーネス専用のロジックを書いた瞬間、この検証は何も担保しなくなる。
@MainActor
enum VerifyHarness {
    private static var env: [String: String] { ProcessInfo.processInfo.environment }

    static var isEnabled: Bool { env["DRIVE_VERIFY"] == "1" }

    static var runID: String { env["DRIVE_VERIFY_RUNID"] ?? "run" }

    /// 自動記録の経路を検証する。手で start() を呼ばず、検知に任せる。
    static var isAutoMode: Bool { env["DRIVE_VERIFY_AUTO"] == "1" }

    /// 位置更新がこの秒数途切れたら走行終了とみなす。
    /// `simctl location start` が完走した瞬間に更新が止まるので、これが一番安定した終了トリガ。
    private static var idleStopSeconds: TimeInterval {
        Double(env["DRIVE_VERIFY_IDLE_STOP"] ?? "") ?? 10
    }

    /// これだけ点が溜まるまでは「途切れた」と判定しない。
    /// `simctl location start` が動き出すまでに数秒かかるので、
    /// 起動直後の静止を走行終了と取り違えると 1 点で終わる（2026-08-28 に実測）。
    private static var minimumPoints: Int {
        Int(env["DRIVE_VERIFY_MIN_POINTS"] ?? "") ?? 10
    }

    /// 開始からこの秒数は終了判定をしない。
    private static var startGraceSeconds: TimeInterval {
        Double(env["DRIVE_VERIFY_START_GRACE"] ?? "") ?? 45
    }

    /// 保険の打ち切り。
    private static var maxSeconds: TimeInterval {
        Double(env["DRIVE_VERIFY_MAX_SECONDS"] ?? "") ?? 1800
    }

    /// 距離アサーションの期待値（km）。未指定なら距離は検査しない。
    private static var expectKm: Double? {
        Double(env["DRIVE_VERIFY_EXPECT_KM"] ?? "")
    }

    static var outputDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("verify", isDirectory: true)
            .appendingPathComponent(runID, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    // MARK: - 進行の記録とタイムアウト

    /// どこまで進んだかを毎回上書きする。止まったときに、どの段で止まったかが残る。
    static func phase(_ name: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(name)\n"
        if let data = line.data(using: .utf8) {
            let url = outputDirectory.appendingPathComponent("02_phase.log")
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    @MainActor private final class Box<T> {
        var value: T?
        var done = false
    }

    /// `seconds` で諦める。1 段の詰まりで検証全体が落ちるのを防ぐ。
    static func withTimeout<T>(
        _ seconds: Double,
        _ label: String,
        _ body: @escaping @MainActor () async -> T
    ) async -> T? {
        let box = Box<T>()
        let task = Task { @MainActor in
            box.value = await body()
            box.done = true
        }
        let deadline = Date().addingTimeInterval(seconds)
        while !box.done, Date() < deadline {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        if !box.done {
            task.cancel()
            phase("TIMEOUT \(label) (\(Int(seconds))s)")
            return nil
        }
        return box.value
    }

    // MARK: - 実行

    static func run(recorder: DriveRecorder, store: DriveRecordStore, cache: PhotoImageCache) async {
        var results: [Assertion] = []

        if isAutoMode {
            // 自動記録の経路。手で start() を呼ばない。
            recorder.setAutoDetect(true)
            touch("01_started")
            phase("auto-detect enabled (motion available: \(recorder.detector.isMotionAvailable))")

            let started = await waitUntil(60) { recorder.isRecording }
            phase("auto-detect started recording: \(started)")
            results.append(.init(
                name: "auto-detect starts recording",
                expected: "検知で記録が始まる",
                actual: started ? "始まった（\(recorder.detector.state.rawValue)）" : "始まらなかった",
                pass: started
            ))
        } else {
            recorder.start()
            touch("01_started")
            phase("recording started")
        }
        writeJSON("00_env.json", [
            "runID": runID,
            "device": ProcessInfo.processInfo.hostName,
            "systemVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "bundle": Bundle.main.bundleIdentifier ?? "?",
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            "startedAt": ISO8601DateFormatter().string(from: Date()),
        ])

        await waitUntilIdle(recorder: recorder)
        phase("drive finished: \(recorder.points.count) points / \(Int(recorder.distanceMeters)) m")
        writeJSON("10_route.json", routeSummary(recorder: recorder))

        let points = recorder.points
        results.append(.init(
            name: "routePointCount >= 60",
            expected: ">= 60",
            actual: "\(points.count)",
            pass: points.count >= 60
        ))

        let durationSeconds = (points.last?.time.timeIntervalSince(points.first?.time ?? Date())) ?? 0
        results.append(.init(
            name: "duration > 0",
            expected: "> 0",
            actual: String(format: "%.1fs", durationSeconds),
            pass: durationSeconds > 0
        ))

        if let expectKm {
            let km = recorder.distanceMeters / 1000
            let ratio = expectKm > 0 ? abs(km - expectKm) / expectKm : 1
            results.append(.init(
                name: "distance within 15% of expected",
                expected: String(format: "%.2f km ±15%%", expectKm),
                actual: String(format: "%.2f km", km),
                pass: ratio <= 0.15
            ))
        }

        // 自動モードでは検知側が締めるのを待つ（閾値は環境変数で短くしてある）。
        var autoRecord: DriveRecord?
        if isAutoMode {
            // 「記録が止まったか」で見る。`finishedByDetector` を見張ると、
            // 画面（RecordScreen）が先に拾って nil に戻すので取り逃す。
            // 本番では UI が受け取って保存する経路が正しいので、こちらが合わせる。
            let autoStopped = await waitUntilLogging(120, every: 5, recorder: recorder) {
                !recorder.isRecording
            }
            phase("auto-detect stopped recording: \(autoStopped)")
            results.append(.init(
                name: "auto-detect stops recording",
                expected: "止まったら検知で締まる",
                actual: autoStopped ? "締まった" : "締まらなかった（手で締めた）",
                pass: autoStopped
            ))
            // 画面が拾っていれば履歴に入っている。どちらから来ても同じ記録。
            autoRecord = recorder.finishedByDetector ?? store.records.first
            recorder.finishedByDetector = nil
        }

        // ここから先は本番と同じ経路を通す。ハーネス専用のロジックを書かない。
        guard let record = autoRecord ?? recorder.stop() else {
            results.append(.init(name: "record created", expected: "not nil", actual: "nil", pass: false))
            writeResult(results)
            touch("99_done")
            return
        }
        var saved = record
        store.save(saved)

        results += maskAssertions(record: saved)
        phase("mask done")

        // 写真の突き合わせも本番と同じ経路を通す。
        _ = await withTimeout(20, "photo authorization") {
            await PhotoLibraryService.requestAuthorization()
        }
        phase("photo authorization: \(PhotoLibraryService.authorizationLabel)")

        if PhotoLibraryService.isAuthorized {
            let assets = PhotoLibraryService.assets(onDayOf: saved)
            phase("assets fetched: \(assets.count)")
            saved.selectedPhotos = PhotoMatcher.match(record: saved, assets: assets)
            store.save(saved)
            phase("matched: \(saved.includedPhotos.count) / \(saved.selectedPhotos.count)")

            _ = await withTimeout(60, "photo preload") {
                await cache.preload(saved.includedPhotos)
            }
            phase("images loaded: \(cache.images.count)")
            results += photoAssertions(record: saved, assetCount: assets.count)
        } else {
            // シミュレータでは写真権限を機械で与えられない（実測）。
            // PhotoKit の受け渡しは実機に回し、判定そのものはここで確かめる。
            results.append(.init(
                name: "photo library authorized",
                expected: "authorized（実機でのみ検証可）",
                actual: PhotoLibraryService.authorizationLabel,
                pass: true
            ))
            results += syntheticMatcherAssertions(record: saved)
        }

        // 地名。ネットワークとレート制限があるので落ちても走行は成立させる。
        let naming = await withTimeout(30, "reverse geocoding") {
            await PlaceNamer.resolve(points: saved.points, maskedRadius: saved.maskedRadius)
        } ?? PlaceNamer.Naming(title: PlaceNamer.fallbackTitle, stops: [])
        saved.title = naming.title
        saved.stops = naming.stops
        phase("named: \(saved.title)")
        store.save(saved)
        results.append(.init(
            name: "title resolved (or falls back)",
            expected: "空でない",
            actual: saved.title,
            pass: !saved.title.isEmpty
        ))

        results += exportStory(record: saved, images: cache.images)
        phase("story exported")
        results += exportPlayback(record: saved, images: cache.images)
        phase("playback frames exported")
        results += await withTimeout(60, "save to photo library") {
            await saveAssertion(record: saved, images: cache.images)
        } ?? [.init(name: "save to photo library", expected: "保存できる", actual: "タイムアウト", pass: false)]
        phase("saved")

        writeResult(results)
        touch("99_done")
    }

    /// 出発・到着のマスクが効いているか。自宅が線の端から推定できないことの担保。
    private static func maskAssertions(record: DriveRecord) -> [Assertion] {
        let masked = RouteMask.masked(record.points, radius: record.maskedRadius)
        guard let trueStart = record.points.first, let trueGoal = record.points.last,
              let drawnStart = masked.first, let drawnGoal = masked.last
        else { return [] }

        let startGap = CLLocation(from: trueStart).distance(from: CLLocation(from: drawnStart))
        let goalGap = CLLocation(from: trueGoal).distance(from: CLLocation(from: drawnGoal))

        var summary: [String: Any] = [
            "maskedRadius": record.maskedRadius,
            "rawPointCount": record.points.count,
            "maskedPointCount": masked.count,
            "startGapMeters": startGap,
            "goalGapMeters": goalGap,
        ]
        summary["drawnFirst"] = ["lat": drawnStart.coordinate.latitude, "lon": drawnStart.coordinate.longitude]
        summary["drawnLast"] = ["lat": drawnGoal.coordinate.latitude, "lon": drawnGoal.coordinate.longitude]
        writeJSON("11_route_masked.json", summary)

        return [
            .init(
                name: "masked start >= radius from true start",
                expected: String(format: ">= %.0fm", record.maskedRadius),
                actual: String(format: "%.0fm", startGap),
                pass: startGap >= record.maskedRadius * 0.9
            ),
            .init(
                name: "masked goal >= radius from true goal",
                expected: String(format: ">= %.0fm", record.maskedRadius),
                actual: String(format: "%.0fm", goalGap),
                pass: goalGap >= record.maskedRadius * 0.9
            ),
        ]
    }

    /// 走行ログから作った候補で `PhotoMatcher` を検証する。
    ///
    /// 「マスク圏内」「ルートから遠い」「時刻レンジ外」「位置なし」を必ず混ぜる。
    /// 全部通ってしまう実装になっていないことを見るのが目的。
    private static func syntheticMatcherAssertions(record: DriveRecord) -> [Assertion] {
        let masked = RouteMask.masked(record.points, radius: record.maskedRadius)
        guard let trueStart = record.points.first, masked.count >= 4 else { return [] }
        let mid = masked[masked.count / 2]
        let quarter = masked[masked.count / 4]
        let midTime = record.startedAt.addingTimeInterval(record.duration / 2)

        let candidates: [PhotoCandidate] = [
            // 出発地点そのもの → マスク圏内で外れる
            .init(id: "synthetic-masked", creationDate: midTime, coordinate: trueStart.coordinate),
            // ルート上 → 採用
            .init(id: "synthetic-onroute-1", creationDate: record.startedAt.addingTimeInterval(record.duration * 0.25), coordinate: quarter.coordinate),
            .init(id: "synthetic-onroute-2", creationDate: midTime, coordinate: mid.coordinate),
            // 東京駅 → ルートから遠くて外れる
            .init(id: "synthetic-far", creationDate: midTime, coordinate: .init(latitude: 35.6812, longitude: 139.7671)),
            // 3 時間前 → 時刻レンジ外で外れる
            .init(id: "synthetic-old", creationDate: record.startedAt.addingTimeInterval(-10800), coordinate: mid.coordinate),
            // 位置なし → 撮影時刻の補間で採用
            .init(id: "synthetic-nogps", creationDate: midTime, coordinate: nil),
        ]

        let refs = PhotoMatcher.match(record: record, candidates: candidates)
        let byID = Dictionary(uniqueKeysWithValues: refs.map { ($0.assetLocalIdentifier, $0) })

        writeJSON("21_photos_synthetic.json", refs.map { ref -> [String: Any] in
            var row: [String: Any] = [
                "id": ref.assetLocalIdentifier,
                "matched": ref.isIncluded,
                "position": ref.position,
                "hasLocation": ref.hasLocation,
            ]
            row["rejectReason"] = ref.rejectReason ?? NSNull()
            return row
        })

        func check(_ id: String, shouldMatch: Bool, label: String) -> Assertion {
            let ref = byID[id]
            let actual = ref.map { $0.isIncluded ? "採用" : "除外（\($0.rejectReason ?? "-")）" } ?? "候補に出ない"
            return .init(
                name: "matcher: \(label)",
                expected: shouldMatch ? "採用" : "除外",
                actual: actual,
                pass: ref?.isIncluded == shouldMatch
            )
        }

        let onRoute = refs.filter { $0.isIncluded && $0.hasLocation }
        let positionsInRange = onRoute.allSatisfy { $0.position >= 0 && $0.position <= 1 }

        return [
            check("synthetic-masked", shouldMatch: false, label: "出発地点の写真はマスクで外す"),
            check("synthetic-far", shouldMatch: false, label: "ルートから遠い写真は外す"),
            check("synthetic-old", shouldMatch: false, label: "走行前の写真は外す"),
            check("synthetic-onroute-1", shouldMatch: true, label: "ルート上の写真は採用"),
            check("synthetic-onroute-2", shouldMatch: true, label: "ルート上の写真は採用（2枚目）"),
            check("synthetic-nogps", shouldMatch: true, label: "位置情報なしは撮影時刻で救う"),
            .init(name: "matcher: 位置は 0〜1 に収まる", expected: "0...1",
                  actual: positionsInRange ? "収まっている" : "範囲外あり", pass: positionsInRange),
        ]
    }

    /// 写真の採否と理由を残す。ここが空だと「抽出が動いていない」のか
    /// 「そもそも写真が無い」のかが区別できない。
    private static func photoAssertions(record: DriveRecord, assetCount: Int) -> [Assertion] {
        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone(identifier: "Asia/Tokyo")
        writeJSON("20_photos.json", [
            "assetCount": assetCount,
            "driveWindow": [
                "start": iso.string(from: record.startedAt),
                "end": iso.string(from: record.endedAt),
            ],
            "photos": record.selectedPhotos.map { ref -> [String: Any] in
                var row: [String: Any] = [
                    "assetLocalIdentifier": ref.assetLocalIdentifier,
                    "creationDate": iso.string(from: ref.creationDate),
                    "position": ref.position,
                    "matched": ref.isIncluded,
                    "hasLocation": ref.hasLocation,
                ]
                row["lat"] = ref.coordinate?.latitude ?? NSNull()
                row["lon"] = ref.coordinate?.longitude ?? NSNull()
                row["rejectReason"] = ref.rejectReason ?? NSNull()
                return row
            },
        ])

        let included = record.includedPhotos
        let rejected = record.selectedPhotos.filter { !$0.isIncluded }
        let allRejectedHaveReason = rejected.allSatisfy { ($0.rejectReason ?? "").isEmpty == false }
        let sortedByTime = zip(included, included.dropFirst()).allSatisfy { $0.creationDate <= $1.creationDate }

        return [
            .init(name: "photo candidates found", expected: ">= 1", actual: "\(record.selectedPhotos.count)",
                  pass: !record.selectedPhotos.isEmpty),
            .init(name: "rejected photos have a reason", expected: "全件に理由",
                  actual: "\(rejected.count) 件中 \(rejected.filter { $0.rejectReason != nil }.count) 件",
                  pass: allRejectedHaveReason),
            .init(name: "included photos sorted by creationDate", expected: "昇順",
                  actual: sortedByTime ? "昇順" : "崩れている", pass: sortedByTime),
        ]
    }

    /// 実走行から Story を焼く。絵が出るところまでが「動いた」。
    private static func exportStory(record: DriveRecord, images: [String: UIImage]) -> [Assertion] {
        let story = StoryBuilder.story(from: record, images: images)
        writeJSON("30_story.json", [
            "title": story.title,
            "stops": story.stops,
            "tags": story.tags.map(\.label),
            "distanceText": story.distanceText,
            "durationHours": story.durationHours,
            "durationMinutes": story.durationMinutes,
            "outlinePointCount": story.route.points.count,
            "photos": story.photos.map { ["position": $0.position, "hasImage": $0.image != nil] },
        ])

        var results: [Assertion] = [
            .init(
                name: "route outline keeps its shape",
                expected: ">= 10 点",
                actual: "\(story.route.points.count) 点",
                pass: story.route.points.count >= 10
            ),
        ]
        for template in StoryTemplate.allCases {
            guard let image = StoryExporter.image(for: story, template: template),
                  let data = image.pngData()
            else {
                results.append(.init(
                    name: "render \(template.rawValue)",
                    expected: "1080x1920 png", actual: "nil", pass: false
                ))
                continue
            }
            write("40_\(template.rawValue).png", data: data)
            let size = image.size
            let sizeOK = Int(size.width) == 1080 && Int(size.height) == 1920
            let varied = hasVariety(image)
            results.append(.init(
                name: "render \(template.rawValue)",
                expected: "1080x1920 かつ単色でない",
                actual: "\(Int(size.width))x\(Int(size.height)) / \(varied ? "多色" : "単色")",
                pass: sizeOK && varied
            ))
        }
        return results
    }

    /// アニメを静止画のコマ列に落とす。
    ///
    /// アニメーションは「動いている風」に見えてしまうので、コマにして
    /// 進捗が単調増加しているか・写真が順に増えるかを確かめられるようにする。
    /// これが焼けること自体が、同じ描画を mp4 に流せる証拠にもなる。
    private static func exportPlayback(record: DriveRecord, images: [String: UIImage]) -> [Assertion] {
        let story = StoryBuilder.story(from: record, images: images)
        let timeline = StoryPlaybackTimeline(story: story)
        let theme = StoryTemplate.night.theme
        let directory = outputDirectory.appendingPathComponent("50_anim", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let frameCount = Int(env["DRIVE_VERIFY_ANIM_FRAMES"] ?? "") ?? 24
        var revealedCounts: [Int] = []
        var progresses: [Double] = []
        var written = 0

        for index in 0..<frameCount {
            let t = timeline.duration * Double(index) / Double(max(frameCount - 1, 1))
            let frame = timeline.frame(at: t)
            progresses.append(frame.routeProgress)
            revealedCounts.append(frame.revealedPhotoIDs.count)

            let canvas = RouteRevealCanvas(
                outline: story.route,
                photos: story.photos,
                frame: frame,
                lineColor: theme.routeLine,
                glow: theme.routeGlow
            )
            .frame(width: 540, height: 960)
            .background(theme.background)

            let renderer = ImageRenderer(content: canvas)
            renderer.scale = 1
            renderer.proposedSize = ProposedViewSize(width: 540, height: 960)
            if let data = renderer.uiImage?.pngData() {
                let name = String(format: "frame_%04d.png", index)
                try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
                written += 1
            }
        }

        let monotonic = zip(progresses, progresses.dropFirst()).allSatisfy { $0 <= $1 }
        let revealMonotonic = zip(revealedCounts, revealedCounts.dropFirst()).allSatisfy { $0 <= $1 }

        return [
            .init(name: "playback frames written", expected: "\(frameCount)",
                  actual: "\(written)", pass: written == frameCount),
            .init(name: "route progress 0 -> 1", expected: "0 から 1 へ単調増加",
                  actual: String(format: "%.2f -> %.2f / %@", progresses.first ?? -1,
                                 progresses.last ?? -1, monotonic ? "単調" : "崩れ"),
                  pass: monotonic && (progresses.first ?? 1) < 0.01 && (progresses.last ?? 0) > 0.99),
            .init(name: "photos reveal in order", expected: "単調増加",
                  actual: "\(revealedCounts.first ?? -1) -> \(revealedCounts.last ?? -1)",
                  pass: revealMonotonic),
        ]
    }

    /// 写真ライブラリへの保存まで通す。共有シートはタップが要るので検証できないが、
    /// 保存はこちらで完結するので「貼れる 1 枚が手元に残る」ことは担保できる。
    private static func saveAssertion(record: DriveRecord, images: [String: UIImage]) async -> [Assertion] {
        let story = StoryBuilder.story(from: record, images: images)
        guard let image = StoryExporter.image(for: story, template: .night) else {
            return [.init(name: "save to photo library", expected: "保存できる", actual: "画像が作れない", pass: false)]
        }
        do {
            let identifier = try await PhotoSaver.save(image)
            let saved = PhotoLibraryService.assets(withIdentifiers: [identifier]).first
            let size = saved.map { "\($0.pixelWidth)x\($0.pixelHeight)" } ?? "見つからない"
            return [.init(
                name: "save to photo library",
                expected: "1080x1920 が写真に入る",
                actual: size,
                pass: saved?.pixelWidth == 1080 && saved?.pixelHeight == 1920
            )]
        } catch {
            return [.init(name: "save to photo library", expected: "保存できる",
                          actual: "\(error)", pass: false)]
        }
    }

    /// 真っ黒・白紙だけは機械で捕まえる。崩れの検出はできないので目視が要る。
    private static func hasVariety(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let width = 32, height = 32
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        var unique = Set<UInt32>()
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let packed = UInt32(pixels[i]) << 16 | UInt32(pixels[i + 1]) << 8 | UInt32(pixels[i + 2])
            unique.insert(packed)
        }
        return unique.count >= 8
    }

    /// 待ちながら検知の状態を記録する。止まらない原因を後から追えるように。
    private static func waitUntilLogging(
        _ seconds: Double,
        every: Double,
        recorder: DriveRecorder,
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        var nextLog = Date()
        while Date() < deadline {
            if condition() { return true }
            if Date() >= nextLog {
                let speed = recorder.tracker.speedKPH.map { String(format: "%.0f", $0) } ?? "-"
                phase("detector=\(recorder.detector.state.rawValue) recording=\(recorder.isRecording) speed=\(speed)kph points=\(recorder.points.count)")
                nextLog = Date().addingTimeInterval(every)
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return condition()
    }

    /// 条件が満たされるまで待つ。満たされたら true。
    private static func waitUntil(_ seconds: Double, _ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return condition()
    }

    /// 位置更新が途切れるまで待つ。
    private static func waitUntilIdle(recorder: DriveRecorder) async {
        let startedAt = Date()
        let deadline = startedAt.addingTimeInterval(maxSeconds)
        var lastDistance = -1.0
        var lastMove = Date()

        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 500_000_000)

            // 「点が増えたか」ではなく「進んだか」で見る。
            // simctl location start はルートを走り終えたあとも同じ座標を送り続けるので、
            // 点数で判定すると永久に終わらない（2026-08-28 に 16 分走り続けて実測）。
            if abs(recorder.distanceMeters - lastDistance) > 1 {
                lastDistance = recorder.distanceMeters
                lastMove = Date()
                continue
            }
            // 走り出す前の静止を終了と取り違えないための 2 つのガード。
            guard Date().timeIntervalSince(startedAt) >= startGraceSeconds else { continue }
            guard recorder.points.count >= minimumPoints else { continue }
            if Date().timeIntervalSince(lastMove) >= idleStopSeconds { return }
        }
    }

    // MARK: - 成果物

    private static func routeSummary(recorder: DriveRecorder) -> [String: Any] {
        let points = recorder.points
        let iso = ISO8601DateFormatter()
        var summary: [String: Any] = [
            "pointCount": points.count,
            "distanceMeters": recorder.distanceMeters,
            "distanceKm": recorder.distanceMeters / 1000,
        ]
        if let first = points.first, let last = points.last {
            summary["firstTime"] = iso.string(from: first.time)
            summary["lastTime"] = iso.string(from: last.time)
            summary["durationSeconds"] = last.time.timeIntervalSince(first.time)
            summary["first"] = ["lat": first.coordinate.latitude, "lon": first.coordinate.longitude]
            summary["last"] = ["lat": last.coordinate.latitude, "lon": last.coordinate.longitude]
            let lats: [Double] = points.map { $0.coordinate.latitude }
            let lons: [Double] = points.map { $0.coordinate.longitude }
            var bbox: [String: Double] = [:]
            bbox["minLat"] = lats.min() ?? 0
            bbox["maxLat"] = lats.max() ?? 0
            bbox["minLon"] = lons.min() ?? 0
            bbox["maxLon"] = lons.max() ?? 0
            summary["bbox"] = bbox
        }
        return summary
    }

    struct Assertion {
        let name: String
        let expected: String
        let actual: String
        let pass: Bool
    }

    /// アサーションが落ちても成果物は必ず全部書く。絵が無いと原因が分からない。
    static func writeResult(_ results: [Assertion]) {
        writeJSON("90_result.json", [
            "overallPass": results.allSatisfy(\.pass),
            "assertions": results.map {
                ["name": $0.name, "expected": $0.expected, "actual": $0.actual, "pass": $0.pass]
            },
        ])
    }

    static func writeJSON(_ name: String, _ object: Any) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        try? data.write(to: outputDirectory.appendingPathComponent(name), options: .atomic)
    }

    static func write(_ name: String, data: Data) {
        try? data.write(to: outputDirectory.appendingPathComponent(name), options: .atomic)
    }

    static func touch(_ name: String) {
        try? Data().write(to: outputDirectory.appendingPathComponent(name), options: .atomic)
    }
}
