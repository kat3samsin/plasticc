import CoreImage
import Foundation
import PlasticcCore

// Develops each photo with every film and lays the prints out in a grid, one row per photo.
// Usage: swift run contact-sheet out.jpg photo1.jpg photo2.jpg …
// A roll folder pulled off the phone (one with a roll.json) stands for its frames, developed as the phone would:
// with each shot's own source, brightness, flash and seed.
// Set PRINTS_DIR to also keep each full-size print there, GLOW=1 to develop with the glow setting on, and
// LEAKS=0 to turn light leaks off.
let args = CommandLine.arguments.dropFirst()
guard args.count >= 2 else {
    print("usage: contact-sheet out.jpg photo.jpg [photo.jpg …]")
    exit(1)
}
let out = URL(fileURLWithPath: args.first!)
let photos: [(url: URL, shot: Roll.Shot?)] = args.dropFirst().flatMap { arg -> [(url: URL, shot: Roll.Shot?)] in
    let url = URL(fileURLWithPath: arg)
    guard let json = try? Data(contentsOf: url.appendingPathComponent("roll.json")),
          let roll = try? JSONDecoder().decode(Roll.self, from: json) else { return [(url, nil)] }
    return roll.shots.map { (url.appendingPathComponent($0.file), $0) }
}
let developer = Developer()
let cell: CGFloat = 520
var sheet = CIImage(color: CIColor(red: 0.95, green: 0.92, blue: 0.86))
    .cropped(to: CGRect(x: 0, y: 0, width: cell * CGFloat(FilmStock.all.count + 1), height: cell * CGFloat(photos.count)))

func place(_ image: CIImage, column: Int, row: Int) {
    let s = (cell - 24) / max(image.extent.width, image.extent.height)
    var img = image.transformed(by: CGAffineTransform(scaleX: s, y: s))
    let x = CGFloat(column) * cell + (cell - img.extent.width) / 2
    let y = CGFloat(photos.count - 1 - row) * cell + (cell - img.extent.height) / 2
    img = img.transformed(by: CGAffineTransform(translationX: x - img.extent.minX, y: y - img.extent.minY))
    sheet = img.composited(over: sheet)
}

for (row, (photo, rollShot)) in photos.enumerated() {
    guard let source = CIImage(contentsOf: photo, options: [.applyOrientationProperty: true]) else { continue }
    place(source, column: 0, row: row)
    for (column, film) in FilmStock.all.enumerated() {
        let shot = rollShot ?? Roll.Shot(file: "", takenAt: Date(), flash: false, seed: UInt64(row * 31 + 7))
        let data = try developer.develop(original: photo, film: film, shot: shot, frameIndex: 4, dateStamp: true,
                                         glow: ProcessInfo.processInfo.environment["GLOW"] == "1",
                                         leaks: ProcessInfo.processInfo.environment["LEAKS"] != "0")
        place(CIImage(data: data)!, column: column + 1, row: row)
        if let dir = ProcessInfo.processInfo.environment["PRINTS_DIR"] {
            try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(row)-\(film.id).jpg"))
        }
    }
}
try CIContext().writeJPEGRepresentation(of: sheet, to: out, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
print("wrote \(out.path)")
