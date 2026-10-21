import CoreImage
import Foundation
import PlasticcCore

// Develops each photo with every film and lays the prints out in a grid, one row per photo.
// Usage: swift run contact-sheet out.jpg photo1.jpg photo2.jpg …
// Set PRINTS_DIR to also keep each full-size print there.
let args = CommandLine.arguments.dropFirst()
guard args.count >= 2 else {
    print("usage: contact-sheet out.jpg photo.jpg [photo.jpg …]")
    exit(1)
}
let out = URL(fileURLWithPath: args.first!)
let photos = args.dropFirst().map { URL(fileURLWithPath: $0) }
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

for (row, photo) in photos.enumerated() {
    guard let source = CIImage(contentsOf: photo, options: [.applyOrientationProperty: true]) else { continue }
    place(source, column: 0, row: row)
    for (column, film) in FilmStock.all.enumerated() {
        let shot = Roll.Shot(file: "", takenAt: Date(), flash: false, seed: UInt64(row * 31 + 7))
        let data = try developer.develop(original: photo, film: film, shot: shot, frameIndex: 4, dateStamp: true)
        place(CIImage(data: data)!, column: column + 1, row: row)
        if let dir = ProcessInfo.processInfo.environment["PRINTS_DIR"] {
            try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(row)-\(film.id).jpg"))
        }
    }
}
try CIContext().writeJPEGRepresentation(of: sheet, to: out, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
print("wrote \(out.path)")
