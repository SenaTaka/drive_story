import PhotosUI
import SwiftUI

/// 自動で拾った写真を確認して外す画面。
///
/// 自動抽出が主で、ここは覆すためだけの場所。全部を手で選ばせると
/// 「40 枚をスクロールして選べずに閉じる」という元の問題に戻る。
struct PhotoSelectScreen: View {
    let recordID: UUID

    @EnvironmentObject private var store: DriveRecordStore
    @EnvironmentObject private var cache: PhotoImageCache
    @State private var picked: [PhotosPickerItem] = []

    private var record: DriveRecord? { store.record(id: recordID) }

    var body: some View {
        List {
            if let record {
                Section {
                    ForEach(record.selectedPhotos) { photo in
                        PhotoRow(
                            photo: photo,
                            image: cache.image(for: photo.assetLocalIdentifier),
                            toggle: { toggle(photo) }
                        )
                    }
                } header: {
                    Text("走行中の写真")
                } footer: {
                    Text("撮影時刻と位置から自動で選んでいます。外したいものはタップでチェックを外してください。")
                }

                Section {
                    PhotosPicker(selection: $picked, matching: .images) {
                        Label("写真を追加", systemImage: "plus")
                    }
                } footer: {
                    Text("自動で拾えなかった 1 枚を足せます。位置情報があれば経路上に、無ければ中間に置きます。")
                }
            } else {
                Text("この記録は見つかりません")
            }
        }
        .navigationTitle("写真")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: picked) { _, items in
            Task { await add(items) }
        }
    }

    private func toggle(_ photo: PhotoRef) {
        guard var record else { return }
        guard let index = record.selectedPhotos.firstIndex(where: { $0.id == photo.id }) else { return }
        record.selectedPhotos[index].isIncluded.toggle()
        // 一度手で外したものを、あとの再抽出で勝手に戻さないための印。
        record.selectedPhotos[index].rejectReason =
            record.selectedPhotos[index].isIncluded ? nil : "手動で外した"
        store.save(record)
    }

    private func add(_ items: [PhotosPickerItem]) async {
        guard var record, !items.isEmpty else { return }
        let identifiers = items.compactMap(\.itemIdentifier)
        let assets = PhotoLibraryService.assets(withIdentifiers: identifiers)
        let existing = Set(record.selectedPhotos.map(\.assetLocalIdentifier))

        let masked = RouteMask.masked(record.points, radius: record.maskedRadius)
        let fractions = masked.cumulativeFractions

        for asset in assets where !existing.contains(asset.localIdentifier) {
            let shotAt = asset.creationDate ?? record.startedAt
            let position: Double
            if asset.location != nil {
                position = PhotoMatcher.match(record: record, assets: [asset]).first?.position
                    ?? PhotoMatcher.positionByTime(shotAt, points: masked, fractions: fractions)
            } else {
                position = PhotoMatcher.positionByTime(shotAt, points: masked, fractions: fractions)
            }
            record.selectedPhotos.append(
                PhotoRef(
                    assetLocalIdentifier: asset.localIdentifier,
                    creationDate: shotAt,
                    coordinate: asset.location?.coordinate,
                    position: position,
                    isIncluded: true,
                    rejectReason: nil
                )
            )
        }
        store.save(record)
        await cache.preload(record.includedPhotos)
        picked = []
    }
}

private struct PhotoRow: View {
    let photo: PhotoRef
    let image: UIImage?
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Group {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(photo.creationDate.formatted(date: .omitted, time: .shortened))
                    HStack(spacing: 6) {
                        if !photo.hasLocation {
                            Text("位置情報なし")
                        }
                        if let reason = photo.rejectReason {
                            Text(reason)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: photo.isIncluded ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(photo.isIncluded ? Color.accentColor : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
