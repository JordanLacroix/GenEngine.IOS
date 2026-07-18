import Foundation

struct FamiliarAssetPack: Codable, Sendable {
    let schemaVersion: Int
    let id: String
    let name: String
    let targetFamiliarId: UUID?
    let bundledAssetName: String?
    let portraitUrl: URL?
    let license: String
    let attribution: String

    static let aster = FamiliarAssetPack(
        schemaVersion: 1,
        id: "genengine.aster.original",
        name: "Aster — constellation",
        targetFamiliarId: nil,
        bundledAssetName: "FamiliarAster",
        portraitUrl: nil,
        license: "GenEngine project asset — no external trademark or ownership metadata",
        attribution: "Illustration originale générée pour GenEngine")

    func validated() throws -> FamiliarAssetPack {
        guard schemaVersion == 1,
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !license.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !attribution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              bundledAssetName != nil || portraitUrl?.scheme == "https" else {
            throw FamiliarAssetPackError.invalidManifest
        }
        return self
    }
}

enum FamiliarAssetPackError: LocalizedError {
    case invalidManifest
    var errorDescription: String? { "Le pack doit utiliser le schéma 1, fournir licence et attribution, puis un asset inclus ou une URL HTTPS." }
}

enum FamiliarAssetPackStore {
    private static let key = "genengine.familiar.asset-pack"

    static func load() -> FamiliarAssetPack {
        guard let data = UserDefaults.standard.data(forKey: key),
              let pack = try? JSONDecoder().decode(FamiliarAssetPack.self, from: data),
              let validated = try? pack.validated() else { return .aster }
        return validated
    }

    static func save(_ pack: FamiliarAssetPack) throws {
        let validated = try pack.validated()
        UserDefaults.standard.set(try JSONEncoder().encode(validated), forKey: key)
    }
}
