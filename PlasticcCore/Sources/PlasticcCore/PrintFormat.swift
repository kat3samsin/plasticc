/// The print's shape, as the lab crops it: 35 mm's 3:2, the phone's own 4:3, or square.
public enum PrintFormat: String, CaseIterable, Codable, Sendable {
    case classic = "3:2"
    case phone = "4:3"
    case square = "1:1"

    /// The long side over the short one.
    public var ratio: Double {
        switch self {
        case .classic: 3.0 / 2.0
        case .phone: 4.0 / 3.0
        case .square: 1
        }
    }
}
