import ImageIO
import Photos
import UIKit

/// Saving kept prints. Add-only access: the app never sees your library.
enum PhotoLibrary {
    enum Problem { case denied, damaged }

    /// Adds the print to Photos, dated when it was shot. Nil on success.
    static func save(_ file: URL, takenAt: Date) async -> Problem? {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .denied }
        guard Thumbnail.load(file, maxPixel: 16) != nil else { return .damaged }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: file, options: nil)
                request.creationDate = takenAt
            }
            return nil
        } catch {
            return .damaged
        }
    }
}

/// Small decoded images for the screens, so a deck of 36 prints doesn't hold 36 full scans.
enum Thumbnail {
    static func make(from data: Data, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return make(from: source, maxPixel: maxPixel)
    }

    static func load(_ url: URL, maxPixel: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = make(from: source, maxPixel: maxPixel) else { return nil }
        return UIImage(cgImage: image)
    }

    private static func make(from source: CGImageSource, maxPixel: Int) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary)
    }
}
