/// How many exposures a roll holds. Any film can be loaded at any length.
public enum RollLength: Int, CaseIterable, Codable, Sendable {
    /// A three-shot roll for trying the whole flow quickly. The app offers it in debug builds only.
    case test = 3
    case short = 12
    case standard = 24
    case long = 36

    public var exposures: Int { rawValue }
}
