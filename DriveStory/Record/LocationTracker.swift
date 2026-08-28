@preconcurrency import CoreLocation
import Combine
import Foundation
import SwiftUI

/// GPS 精度の言語化。数値だけでは「今ちゃんと録れているのか」が伝わらない。
enum GPSQuality {
    case unavailable  // 取得できていない
    case low          // 低精度（> 25m）: 軌跡が汚れる
    case normal       // 通常（10〜25m）
    case good         // 良好（< 10m）

    var label: String {
        switch self {
        case .unavailable: return "利用不可"
        case .low: return "低精度"
        case .normal: return "通常"
        case .good: return "良好"
        }
    }

    var color: Color {
        switch self {
        case .unavailable: return .gray
        case .low: return .red
        case .normal: return .orange
        case .good: return .green
        }
    }
}

/// 位置情報の取得だけを担う層。軌跡は溜め込まず `onPoint` で外へ出す。
///
/// `../car_ui` の `LocationModel` からの移植。あちらは取得した点を
/// テレメトリ記録層と軌跡ストアへ直接押し込んでいたので、その依存を外して
/// 「誰に渡すか」を呼び出し側（`DriveRecorder`）が決める形にした。
final class LocationTracker: NSObject, ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isDenied = false
    @Published private(set) var speedKPH: Double?
    @Published private(set) var horizontalAccuracyM: Double?
    /// 記録開始からの積算距離（m）。精度の悪い点では加算しない。
    @Published private(set) var totalDistanceMeters: Double = 0

    /// 精度フィルタを通った点。軌跡に載せてよいものだけが流れてくる。
    var onPoint: ((CLLocation) -> Void)?
    /// 精度に関わらず届いた位置。運転の自動検知に使う（速度だけ見るので粗くてよい）。
    var onRawLocation: ((CLLocation) -> Void)?

    /// 画面を閉じても記録を続けるか。自動記録を使うときに立てる。
    /// Always 権限がないと `allowsBackgroundLocationUpdates` は設定できない。
    @Published private(set) var isBackgroundEnabled = false

    var quality: GPSQuality {
        guard isActive, let accuracy = horizontalAccuracyM else { return .unavailable }
        switch accuracy {
        case ..<10: return .good
        case ..<25: return .normal
        default: return .low
        }
    }

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?

    /// 距離を加算してよい水平精度の上限（m）。これより粗い点はノイズで距離が膨らむ。
    private let distanceAccuracyLimit: CLLocationAccuracy = 50
    /// 軌跡に載せてよい水平精度の上限（m）。
    private let trackAccuracyLimit: CLLocationAccuracy = 100
    /// この距離未満の移動は加算しない（停車中のふらつきを距離にしない）。
    private let minMovementMeters: CLLocationDistance = 1

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        // 信号待ちで自動停止されると軌跡が切れるので切っておく。
        manager.pausesLocationUpdatesAutomatically = false
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isDenied = true
        default:
            beginUpdates()
        }
    }

    /// 画面を閉じている間も記録を続けたいときに呼ぶ。
    ///
    /// PRD では当初 Always を使わない方針だったが、走り出しを自動で捉えるには
    /// アプリを開いていない間も位置が要る（2026-08-29 に方針変更）。
    /// 常時 GPS は電池を食うので、自動記録が ON のときだけ使う。
    func enableBackground() {
        switch manager.authorizationStatus {
        case .notDetermined, .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            isDenied = true
            return
        default:
            break
        }
        applyBackgroundMode()
        // アプリが落とされても走り出しで起こしてもらうための保険。
        manager.startMonitoringSignificantLocationChanges()
        beginUpdates()
    }

    func disableBackground() {
        isBackgroundEnabled = false
        manager.allowsBackgroundLocationUpdates = false
        manager.stopMonitoringSignificantLocationChanges()
    }

    private func applyBackgroundMode() {
        guard manager.authorizationStatus == .authorizedAlways else { return }
        manager.allowsBackgroundLocationUpdates = true
        // 背景で位置を取っていることは利用者に見えていないといけない。
        manager.showsBackgroundLocationIndicator = true
        isBackgroundEnabled = true
    }

    func stop() {
        manager.stopUpdatingLocation()
        isActive = false
        lastLocation = nil
    }

    func resetDistance() {
        totalDistanceMeters = 0
        lastLocation = nil
    }

    private func beginUpdates() {
        isDenied = false
        isActive = true
        manager.startUpdatingLocation()
    }

    private func apply(_ location: CLLocation) {
        // 自動検知は速度しか見ないので、精度フィルタの前に渡す。
        onRawLocation?(location)

        horizontalAccuracyM = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
        speedKPH = location.speed >= 0 ? location.speed * 3.6 : nil

        if let lastLocation,
           location.horizontalAccuracy >= 0,
           location.horizontalAccuracy < distanceAccuracyLimit {
            let delta = location.distance(from: lastLocation)
            if delta > minMovementMeters {
                totalDistanceMeters += delta
                self.lastLocation = location
            }
        } else {
            lastLocation = location
        }

        // 精度の悪い点は軌跡を汚すので渡さない。
        if location.horizontalAccuracy >= 0, location.horizontalAccuracy < trackAccuracyLimit {
            onPoint?(location)
        }
    }
}

extension LocationTracker: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            applyBackgroundMode()
            if isActive || lastLocation == nil {
                beginUpdates()
            }
        case .denied, .restricted:
            isDenied = true
            isActive = false
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isActive else { return }
        locations.forEach(apply)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 一時的な取得失敗は無視して次の更新を待つ。
    }
}
