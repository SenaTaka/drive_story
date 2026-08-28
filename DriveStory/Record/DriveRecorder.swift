import Combine
import CoreLocation
import Foundation

/// 走行 1 回ぶんの記録。開始から終了までを 1 セッションとして持つ。
///
/// `../car_ui` の `DriveSessionManager`（セッションの開始/終了と経過時間）と
/// `TrackStore`（1Hz 間引きと軌跡の保持）を合わせたもの。あちらの軌跡は
/// アプリ全体で 1 本の連続バッファだったが、こちらは 1 ドライブ = 1 本にする。
@MainActor
final class DriveRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var startedAt: Date?
    @Published private(set) var points: [RoutePoint] = []
    /// 積算距離（m）。マスク前の全量で、走った事実そのもの。
    @Published private(set) var distanceMeters: Double = 0
    /// 中断した記録を復元したときに立つ。保存するか捨てるかを利用者に選ばせる。
    @Published private(set) var hasRecoveredSession = false

    /// 出発・到着を伏せる半径（m）。記録時に確定して `DriveRecord` に持たせる。
    var maskedRadius: Double {
        get { UserDefaults.standard.object(forKey: "maskedRadius") as? Double ?? 500 }
        set { UserDefaults.standard.set(newValue, forKey: "maskedRadius") }
    }

    let tracker = LocationTracker()
    let detector = DriveDetector()

    /// 自動記録。走り出しを勝手に捉えて記録を始め、止まったら締める。
    /// Always 権限と常時 GPS が要るので既定は切ってある。
    @Published private(set) var isAutoDetectEnabled = false

    /// 自動で締めた記録。UI が拾って保存する。
    @Published var finishedByDetector: DriveRecord?

    private var nextID = 0
    private var lastRecordTime: Date?
    private var lastPersist = Date()
    /// 記録中にディスクへ退避する間隔。
    private let persistInterval: TimeInterval = 60

    /// この間隔より短い更新は間引く（GPS は 1 秒に何度も飛んでくる）。
    /// 上限に当たると倍化していく。
    private var minInterval: TimeInterval = 1.0
    /// 上限。1 秒間隔で 6 時間ぶん。
    private let maxPoints = 21_600

    init() {
        tracker.onPoint = { [weak self] location in
            // CLLocationManager の delegate は manager を作ったスレッド（= main）に来る。
            // 念のため取り違えても落ちないようにしておく。
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.record(location) }
            } else {
                DispatchQueue.main.async { self?.record(location) }
            }
        }
        tracker.onRawLocation = { [weak self] location in
            guard let self else { return }
            if Thread.isMainThread {
                MainActor.assumeIsolated { self.detector.consume(location) }
            } else {
                DispatchQueue.main.async { self.detector.consume(location) }
            }
        }
        detector.onStart = { [weak self] in
            guard let self, !self.isRecording else { return }
            self.start()
        }
        detector.onStop = { [weak self] in
            guard let self, self.isRecording else { return }
            self.finishedByDetector = self.stop()
        }
        restoreInflight()
    }

    // MARK: - 自動記録

    func setAutoDetect(_ enabled: Bool) {
        isAutoDetectEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "autoDetectEnabled")
        if enabled {
            tracker.enableBackground()
            detector.enable()
            detector.syncRecording(isRecording)
        } else {
            detector.disable()
            tracker.disableBackground()
            if !isRecording { tracker.stop() }
        }
    }

    /// 起動時に前回の設定を復元する。
    func restoreAutoDetect() {
        guard UserDefaults.standard.bool(forKey: "autoDetectEnabled") else { return }
        setAutoDetect(true)
    }

    // MARK: - セッション

    func start() {
        points = []
        nextID = 0
        lastRecordTime = nil
        minInterval = 1.0
        distanceMeters = 0
        startedAt = Date()
        isRecording = true
        hasRecoveredSession = false
        lastPersist = Date()
        tracker.resetDistance()
        tracker.start()
        detector.syncRecording(true)
    }

    /// 記録を止めて `DriveRecord` にする。2 点未満なら記録として成立しないので nil。
    @discardableResult
    func stop() -> DriveRecord? {
        isRecording = false
        detector.syncRecording(false)
        // 自動記録中は次の走り出しを待つので位置取得を止めない。
        if !isAutoDetectEnabled { tracker.stop() }
        defer { clearInflight() }
        guard let startedAt, points.count >= 2 else {
            hasRecoveredSession = false
            return nil
        }
        hasRecoveredSession = false
        return DriveRecord(
            startedAt: startedAt,
            endedAt: points.last?.time ?? Date(),
            points: points,
            distanceMeters: distanceMeters,
            maskedRadius: maskedRadius
        )
    }

    /// 復元した中断セッションを捨てる。
    func discardRecoveredSession() {
        points = []
        startedAt = nil
        distanceMeters = 0
        hasRecoveredSession = false
        clearInflight()
    }

    /// 経過秒（未記録なら 0）。
    func elapsed(now: Date = Date()) -> TimeInterval {
        guard let startedAt else { return 0 }
        return now.timeIntervalSince(startedAt)
    }

    /// `H:MM:SS` / `M:SS` 形式の経過時間。
    func elapsedText(now: Date = Date()) -> String {
        let total = Int(elapsed(now: now))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    // MARK: - 記録

    private func record(_ location: CLLocation) {
        guard isRecording else { return }
        let now = location.timestamp
        if let lastRecordTime, now.timeIntervalSince(lastRecordTime) < minInterval { return }
        lastRecordTime = now

        nextID += 1
        points.append(
            RoutePoint(
                id: nextID,
                time: now,
                coordinate: location.coordinate,
                speedKPH: location.speed >= 0 ? location.speed * 3.6 : nil
            )
        )

        // 上限に当たったら先頭を捨てるのではなく、間引いて間隔を倍にする。
        // 先頭を捨てると START が消えてルートの形が変わってしまう。
        if points.count > maxPoints {
            points = points.enumerated().compactMap { $0.offset.isMultiple(of: 2) ? $0.element : nil }
            minInterval *= 2
        }

        distanceMeters = tracker.totalDistanceMeters

        if now.timeIntervalSince(lastPersist) > persistInterval {
            persistInflight()
        }
    }

    // MARK: - 記録中の退避
    //
    // 走行中にアプリが落ちると、そこまでの軌跡が丸ごと消える。
    // 60 秒ごとと背面移行時にディスクへ書いておく（`../car_ui` と同じ考え方）。

    nonisolated private static var inflightURL: URL {
        DriveRecordStore.directory.appendingPathComponent("inflight.json")
    }

    private struct Inflight: Codable {
        var startedAt: Date
        var points: [RoutePoint]
        var distanceMeters: Double
    }

    func persistInflight() {
        lastPersist = Date()
        guard let startedAt, !points.isEmpty else { return }
        let snapshot = Inflight(startedAt: startedAt, points: points, distanceMeters: distanceMeters)
        Task.detached(priority: .utility) {
            guard let data = try? DriveRecordStore.encoder.encode(snapshot) else { return }
            try? data.write(to: Self.inflightURL, options: .atomic)
        }
    }

    private func restoreInflight() {
        guard let data = try? Data(contentsOf: Self.inflightURL),
              let restored = try? DriveRecordStore.decoder.decode(Inflight.self, from: data),
              restored.points.count >= 2
        else { return }
        startedAt = restored.startedAt
        points = restored.points
        distanceMeters = restored.distanceMeters
        nextID = restored.points.map(\.id).max() ?? 0
        hasRecoveredSession = true
    }

    private func clearInflight() {
        try? FileManager.default.removeItem(at: Self.inflightURL)
    }
}
