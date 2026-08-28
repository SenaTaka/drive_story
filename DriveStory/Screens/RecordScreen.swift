import SwiftUI

/// ホーム。走行の開始と終了をここで行う。
///
/// 記録中も同じ画面で状態を出す（画面を分けると「今録れているのか」が見えなくなる）。
struct RecordScreen: View {
    @Binding var path: [Route]
    @EnvironmentObject private var recorder: DriveRecorder
    @EnvironmentObject private var store: DriveRecordStore
    @EnvironmentObject private var cache: PhotoImageCache

    var body: some View {
        List {
            Section {
                if recorder.tracker.isDenied {
                    DeniedNotice()
                } else if recorder.isRecording {
                    RecordingStatus(recorder: recorder)
                    Button("走行を終了", role: .destructive) { finish() }
                } else if recorder.hasRecoveredSession {
                    RecoveredNotice(recorder: recorder)
                    Button("この記録を保存") { finish() }
                    Button("捨てる", role: .destructive) { recorder.discardRecoveredSession() }
                } else {
                    Button {
                        recorder.start()
                    } label: {
                        Label("走行を開始", systemImage: "record.circle")
                    }
                }
            } header: {
                Text("記録")
            }

            if !store.records.isEmpty {
                Section {
                    ForEach(store.records) { record in
                        NavigationLink(value: Route.record(record.id)) {
                            RecordRow(record: record)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { store.records[$0].id }.forEach(store.delete)
                    }
                } header: {
                    Text("履歴")
                }
            }

            Section {
                ForEach(SampleDrives.all.indices, id: \.self) { index in
                    NavigationLink(value: Route.sampleStory(index)) {
                        SampleRow(story: SampleDrives.all[index])
                    }
                }
            } header: {
                Text("サンプル")
            } footer: {
                Text("レンダラの検証用ダミー。実走行が入るまでの確認用。")
            }
        }
        .navigationTitle("Drive Story")
    }

    /// 走行を締めて保存し、そのまま Story プレビューへ。
    /// 「走り終わった直後に絵が出ている」がこのアプリの一番大事な体験なので、
    /// 保存して一覧に戻す、という遷移にはしない。
    private func finish() {
        guard let record = recorder.stop() else { return }
        store.save(record)
        path.append(.record(record.id))

        // 写真の突き合わせは待たせない。先に絵を出して、揃った順に差し込む。
        Task {
            var updated = record
            await PhotoLibraryService.requestAuthorization()
            guard PhotoLibraryService.isAuthorized else { return }
            updated.selectedPhotos = PhotoMatcher.match(
                record: updated,
                assets: PhotoLibraryService.assets(onDayOf: updated)
            )
            store.save(updated)
            await cache.preload(updated.includedPhotos)

            // 地名は待たせない。取れたら差し替える（オフラインなら DRIVE のまま）。
            let naming = await PlaceNamer.resolve(
                points: updated.points, maskedRadius: updated.maskedRadius
            )
            updated.title = naming.title
            updated.stops = naming.stops
            store.save(updated)
        }
    }

    static func km(_ meters: Double) -> String {
        String(format: "%.2f", meters / 1000)
    }
}

/// 記録中の状態。経過時間は 1 秒ごとに引き直す。
private struct RecordingStatus: View {
    @ObservedObject var recorder: DriveRecorder

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(recorder.elapsedText(now: context.date))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Spacer()
                    Text("\(RecordScreen.km(recorder.distanceMeters)) km")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }

                HStack(spacing: 12) {
                    Label {
                        Text("GPS \(recorder.tracker.quality.label)")
                    } icon: {
                        Circle()
                            .fill(recorder.tracker.quality.color)
                            .frame(width: 8, height: 8)
                    }
                    Text("\(recorder.points.count) 点")
                    if let speed = recorder.tracker.speedKPH {
                        Text("\(Int(speed)) km/h")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

/// アプリが落ちた走行の復元。捨てるか保存するかを選ばせる。
private struct RecoveredNotice: View {
    @ObservedObject var recorder: DriveRecorder

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("中断した記録があります")
                .font(.subheadline.weight(.semibold))
            Text("\(recorder.points.count) 点 ・ \(RecordScreen.km(recorder.distanceMeters)) km")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct DeniedNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("位置情報が使えません")
                .font(.subheadline.weight(.semibold))
            Text("設定 → プライバシーとセキュリティ → 位置情報サービス から、このアプリに「使用中のみ許可」を与えてください。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct RecordRow: View {
    let record: DriveRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.title.isEmpty ? record.startedAt.formatted(date: .abbreviated, time: .shortened) : record.title)
            Text("\(RecordScreen.km(record.distanceMeters)) km ・ \(record.points.count) 点")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SampleRow: View {
    let story: DriveStory

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(story.title.replacingOccurrences(of: "\n", with: " "))
            Text("\(story.distanceText) km ・ \(story.durationHours)h \(story.durationMinutes)m")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { RecordScreen(path: .constant([])) }
        .environmentObject(DriveRecorder())
        .environmentObject(DriveRecordStore())
        .environmentObject(PhotoImageCache())
        .preferredColorScheme(.dark)
}
