/// What kind of picture a shot's original file holds, which decides how the lab reads it.
public enum CaptureSource: String, Codable, Sendable {
    /// The iPhone's own processed photo: sharpened, noise-reduced and tone-mapped, white clipped at 1.
    case phone
    /// Developed from the sensor's Bayer RAW with no sharpening or tone mapping: scene-linear light divided by
    /// `rawHeadroom`, so highlights up to that many times diffuse white survive, stored as sRGB-encoded 10-bit.
    case raw

    /// Linear light that a RAW original's full white stands for: about 2.5 stops above diffuse white.
    public static let rawHeadroom = 4.0
}
