/// How many exposures a roll holds. Any film can be loaded at any length.
public enum RollLength: Int, CaseIterable, Codable, Sendable {
    case short = 12
    case standard = 24
    case long = 36

    public var exposures: Int { rawValue }
}
