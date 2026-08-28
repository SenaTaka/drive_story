import Combine
import CoreLocation
import CoreMotion
import Foundation

/// 「いま運転しているか」を判定して、記録の開始と終了を自動で決める。
///
/// 判定は 2 系統。どちらか片方が使えなくても機能を落とさない。
///   1. Core Motion の `.automotive` — 実機での本命。GPS より早く・確実に車だと分かる
///   2. GPS 速度の持続 — Core Motion が使えない端末とシミュレータのフォールバック
///
/// シミュレータでは `CMMotionActivityManager.isActivityAvailable()` が false なので、
/// 2 だけで動く。だからこの機能はシミュレータでも検証できる。
@MainActor
final class DriveDetector: ObservableObject {
    /// 判定の閾値。検証で短くできるよう環境変数で上書きできる。
    struct Thresholds {
        /// この速度を超えたら「走っているかもしれない」。
        var startSpeedKPH: Double = 25
        /// 上を満たし続けたら開始する秒数。信号待ちの発進や自転車で誤爆しないための猶予。
        var startSustainSeconds: TimeInterval = 20
        /// この速度を下回ったら「止まったかもしれない」。
        var stopSpeedKPH: Double = 5
        /// 上を満たし続けたら終了する秒数。信号待ちで切らないために長めに取る。
        var stopSustainSeconds: TimeInterval = 180

        static func fromEnvironment() -> Thresholds {
            let env = ProcessInfo.processInfo.environment
            var t = Thresholds()
            if let v = Double(env["DRIVE_DETECT_START_KPH"] ?? "") { t.startSpeedKPH = v }
            if let v = Double(env["DRIVE_DETECT_START_SEC"] ?? "") { t.startSustainSeconds = v }
            if let v = Double(env["DRIVE_DETECT_STOP_KPH"] ?? "") { t.stopSpeedKPH = v }
            if let v = Double(env["DRIVE_DETECT_STOP_SEC"] ?? "") { t.stopSustainSeconds = v }
            return t
        }
    }

    enum State: String {
        case off            // 自動記録が切られている
        case waiting        // 走り出すのを待っている
        case maybeDriving   // 速度は出ているが、まだ確定していない
        case driving        // 記録中
        case maybeStopped   // 止まったように見えるが、信号待ちかもしれない
    }

    @Published private(set) var state: State = .off
    /// Core Motion が車だと言っているか。実機のみ。
    @Published private(set) var motionSaysAutomotive = false

    /// 記録を始めてほしい / 終えてほしいときに呼ぶ。
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?

    var thresholds = Thresholds.fromEnvironment()

    private let motion = CMMotionActivityManager()
    private var fastSince: Date?
    private var slowSince: Date?
    private var lastCoordinate: CLLocationCoordinate2D?
    private var lastMoveAt: Date?

    /// 実際に動いたとみなす最小の移動量（m）。
    private let movementThreshold: CLLocationDistance = 20
    /// この秒数動いていなければ、報告された速度がいくつでも止まっているとみなす。
    private let stillWindow: TimeInterval = 10

    var isMotionAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }

    // MARK: - 開始 / 停止

    func enable() {
        guard state == .off else { return }
        state = .waiting
        fastSince = nil
        slowSince = nil
        lastCoordinate = nil
        lastMoveAt = nil
        startMotionUpdates()
    }

    func disable() {
        state = .off
        fastSince = nil
        slowSince = nil
        motion.stopActivityUpdates()
    }

    /// 記録側が手で開始/終了したときに状態を合わせる。
    func syncRecording(_ isRecording: Bool) {
        guard state != .off else { return }
        state = isRecording ? .driving : .waiting
        fastSince = nil
        slowSince = nil
    }

    // MARK: - 判定

    /// 位置更新のたびに呼ぶ。
    func consume(_ location: CLLocation, now: Date = Date()) {
        guard state != .off else { return }

        // 実際に動いたかを見る。報告された速度だけを信じると、
        // 速度が更新されないまま同じ場所を送り続ける端末で止まったことに気づけない
        // （シミュレータで実測。走り終わっても 144km/h のままだった）。
        if let last = lastCoordinate {
            let moved = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: location)
            if moved >= movementThreshold {
                lastMoveAt = now
                lastCoordinate = location.coordinate
            }
        } else {
            lastCoordinate = location.coordinate
            lastMoveAt = now
        }

        let movingRecently = lastMoveAt.map { now.timeIntervalSince($0) < stillWindow } ?? true
        let reported = location.speed >= 0 ? location.speed * 3.6 : 0
        // 動いていないなら速度の申告は無視する。
        let kph = movingRecently ? reported : 0

        let looksFast = kph >= thresholds.startSpeedKPH || motionSaysAutomotive
        let looksStopped = kph < thresholds.stopSpeedKPH && !motionSaysAutomotive

        switch state {
        case .off:
            return

        case .waiting, .maybeDriving:
            if looksFast {
                let since = fastSince ?? now
                fastSince = since
                state = .maybeDriving
                if now.timeIntervalSince(since) >= thresholds.startSustainSeconds {
                    state = .driving
                    fastSince = nil
                    slowSince = nil
                    onStart?()
                }
            } else {
                fastSince = nil
                state = .waiting
            }

        case .driving, .maybeStopped:
            if looksStopped {
                let since = slowSince ?? now
                slowSince = since
                state = .maybeStopped
                if now.timeIntervalSince(since) >= thresholds.stopSustainSeconds {
                    state = .waiting
                    slowSince = nil
                    fastSince = nil
                    onStop?()
                }
            } else {
                slowSince = nil
                state = .driving
            }
        }
    }

    // MARK: - Core Motion

    private func startMotionUpdates() {
        guard isMotionAvailable else { return }
        motion.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            // low は誤検知が多い。medium 以上でだけ車だと認める。
            let confident = activity.confidence != .low
            self.motionSaysAutomotive = activity.automotive && confident
        }
    }
}
