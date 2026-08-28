// make-exif-photo.swift — 撮影時刻と GPS を持つ JPEG を作る。
//
// このマシンには exiftool も Pillow も piexif も無く、sips は EXIF を扱えない。
// ImageIO なら追加インストール無しで書ける。
//
//   swift scripts/make-exif-photo.swift <out.jpg> <lat|-> <lon|-> "<yyyy:MM:dd HH:mm:ss>" "<label>"
//
// lat/lon に "-" を渡すと GPS 辞書ごと省略する（位置情報なし写真のケース用）。
// 絵には大きく連番とラベルを描く。Story に並んだとき「時刻順か」を目で判定するため、
// 中身が識別できないと検証にならない。

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if canImport(CoreText)
import CoreText
#endif

let args = CommandLine.arguments
guard args.count >= 6 else {
    FileHandle.standardError.write(
        "usage: make-exif-photo.swift <out.jpg> <lat|-> <lon|-> \"<yyyy:MM:dd HH:mm:ss>\" \"<label>\"\n"
            .data(using: .utf8)!)
    exit(2)
}

let outPath = args[1]
let latArg = args[2]
let lonArg = args[3]
let shotAt = args[4]
let label = args[5]

let width = 1200
let height = 1600

// --- 絵を描く ---------------------------------------------------------------
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write("CGContext を作れない\n".data(using: .utf8)!)
    exit(1)
}

// ラベルの先頭 2 文字（連番）で背景色を振る。並び順が色でも分かる。
let seed = Double(abs(label.hashValue % 360)) / 360.0
ctx.setFillColor(CGColor(red: 0.15 + seed * 0.5, green: 0.25, blue: 0.55 - seed * 0.3, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

func draw(_ text: String, size: CGFloat, y: CGFloat) {
    // AppKit/UIKit を使わないので NSAttributedString.Key ではなく CoreText のキーを直接使う。
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
    ]
    let attributed = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attributed)
    let bounds = CTLineGetBoundsWithOptions(line, [])
    ctx.textPosition = CGPoint(x: (CGFloat(width) - bounds.width) / 2, y: y)
    CTLineDraw(line, ctx)
}

draw(label, size: 260, y: CGFloat(height) / 2)
draw(shotAt, size: 56, y: CGFloat(height) / 2 - 160)

guard let image = ctx.makeImage() else {
    FileHandle.standardError.write("makeImage 失敗\n".data(using: .utf8)!)
    exit(1)
}

// --- メタデータ -------------------------------------------------------------
var exif: [CFString: Any] = [
    kCGImagePropertyExifDateTimeOriginal: shotAt,
    kCGImagePropertyExifDateTimeDigitized: shotAt,
    // タイムゾーンを明示しないと Photos の解釈が端末依存になり、
    // 「走行時刻レンジと一致するか」の判定が静かにずれる。
    kCGImagePropertyExifOffsetTimeOriginal: "+09:00",
]
exif[kCGImagePropertyExifOffsetTime] = "+09:00"

var properties: [CFString: Any] = [
    kCGImagePropertyExifDictionary: exif,
    kCGImagePropertyTIFFDictionary: [
        kCGImagePropertyTIFFDateTime: shotAt,
        kCGImagePropertyTIFFMake: "Apple",
        kCGImagePropertyTIFFModel: "iPhone 15 Pro",
    ] as [CFString: Any],
]

if latArg != "-", lonArg != "-", let lat = Double(latArg), let lon = Double(lonArg) {
    // "yyyy:MM:dd HH:mm:ss"（JST）を UTC の GPS 日時に直す。
    let parser = DateFormatter()
    parser.dateFormat = "yyyy:MM:dd HH:mm:ss"
    parser.timeZone = TimeZone(secondsFromGMT: 9 * 3600)
    let shotDate = parser.date(from: shotAt) ?? Date()

    let dayFormatter = DateFormatter()
    dayFormatter.dateFormat = "yyyy:MM:dd"
    dayFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm:ss"
    timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    properties[kCGImagePropertyGPSDictionary] = [
        kCGImagePropertyGPSLatitude: abs(lat),
        kCGImagePropertyGPSLatitudeRef: lat >= 0 ? "N" : "S",
        kCGImagePropertyGPSLongitude: abs(lon),
        kCGImagePropertyGPSLongitudeRef: lon >= 0 ? "E" : "W",
        kCGImagePropertyGPSDateStamp: dayFormatter.string(from: shotDate),
        kCGImagePropertyGPSTimeStamp: timeFormatter.string(from: shotDate),
    ] as [CFString: Any]
}

let url = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write("CGImageDestination を作れない\n".data(using: .utf8)!)
    exit(1)
}
CGImageDestinationAddImage(dest, image, properties as CFDictionary)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write("finalize 失敗\n".data(using: .utf8)!)
    exit(1)
}

print("\(outPath) \(shotAt) \(latArg),\(lonArg)")
