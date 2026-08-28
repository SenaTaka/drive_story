// read-exif.swift — exiftool の代替。撮影時刻と GPS を読み戻して検算する。
//
//   swift scripts/read-exif.swift <file.jpg> [<file.jpg> ...]

import Foundation
import ImageIO

let files = Array(CommandLine.arguments.dropFirst())
guard !files.isEmpty else {
    FileHandle.standardError.write("usage: read-exif.swift <file.jpg> ...\n".data(using: .utf8)!)
    exit(2)
}

var failed = false
for path in files {
    let name = (path as NSString).lastPathComponent
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    else {
        print("\(name)  読めない")
        failed = true
        continue
    }

    let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
    let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]

    let shot = exif[kCGImagePropertyExifDateTimeOriginal] as? String ?? "-"
    let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String ?? "-"

    var location = "なし"
    if let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
       let lon = gps[kCGImagePropertyGPSLongitude] as? Double {
        let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String ?? "N"
        let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String ?? "E"
        let signedLat = latRef == "S" ? -lat : lat
        let signedLon = lonRef == "W" ? -lon : lon
        location = String(format: "%.4f,%.4f", signedLat, signedLon)
    }

    print("\(name)  DateTimeOriginal=\(shot)  Offset=\(offset)  GPS=\(location)")
    if shot == "-" { failed = true }
}

exit(failed ? 1 : 0)
