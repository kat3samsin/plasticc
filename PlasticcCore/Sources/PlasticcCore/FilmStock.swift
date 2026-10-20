/// A film you can load into the camera. The look parameters arrive with the develop engine.
public struct FilmStock: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String

    public static let superia400 = FilmStock(id: "superia400", name: "Fujifilm Superia X-TRA 400")
    public static let portra800 = FilmStock(id: "portra800", name: "Kodak Portra 800")
    public static let hp5 = FilmStock(id: "hp5", name: "Ilford HP5 Plus 400")

    public static let all = [superia400, portra800, hp5]

    public static func with(id: String) -> FilmStock? {
        all.first { $0.id == id }
    }
}
