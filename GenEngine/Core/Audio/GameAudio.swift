import Foundation

/// Ambiances longues, associées à un lieu de l'application plutôt qu'à un écran technique.
/// Le nom brut sert de clé de manifeste : il fait partie du contrat des assets.
enum AudioAmbience: String, CaseIterable, Sendable {
    case welcome
    case home
    case library
    case world
    case studio
    case administration
    case account
    case session

    var label: String {
        switch self {
        case .welcome: "Accueil public"
        case .home: "Vestibule"
        case .library: "Bibliothèque"
        case .world: "Univers du joueur"
        case .studio: "Studio"
        case .administration: "Administration"
        case .account: "Compte"
        case .session: "Partie en cours"
        }
    }
}

/// Signatures courtes. `gameOver` est une musique de fin, pas un bruitage : elle est
/// jouée sur la couche musique et n'est jamais bouclée.
enum AudioCue: String, CaseIterable, Sendable {
    case choice
    case error
    case reward
    case gameOver

    /// Couche de mixage : chaque couche a son propre volume et peut être coupée seule.
    var layer: AudioLayer {
        switch self {
        case .choice, .error, .reward: .effects
        case .gameOver: .music
        }
    }

    var label: String {
        switch self {
        case .choice: "Choix"
        case .error: "Erreur"
        case .reward: "Récompense"
        case .gameOver: "Fin de partie"
        }
    }
}

enum AudioLayer: String, CaseIterable, Sendable {
    case ambience
    case music
    case effects

    var label: String {
        switch self {
        case .ambience: "Ambiance"
        case .music: "Musique"
        case .effects: "Signaux"
        }
    }
}

/// Réglages persistés localement. Aucun réglage sonore n'est envoyé au backend :
/// il ne publie aucun contrat audio à ce jour.
struct AudioSettings: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var ambienceVolume: Double
    var musicVolume: Double
    var effectsVolume: Double

    /// Défauts repris de la direction sonore de référence (ambiance 0,18 ; musique 0,42).
    static let `default` = AudioSettings(isEnabled: true, ambienceVolume: 0.18, musicVolume: 0.42, effectsVolume: 0.7)

    func volume(for layer: AudioLayer) -> Double {
        guard isEnabled else { return 0 }
        return switch layer {
        case .ambience: ambienceVolume
        case .music: musicVolume
        case .effects: effectsVolume
        }
    }

    mutating func setVolume(_ value: Double, for layer: AudioLayer) {
        let clamped = min(max(value, 0), 1)
        switch layer {
        case .ambience: ambienceVolume = clamped
        case .music: musicVolume = clamped
        case .effects: effectsVolume = clamped
        }
    }
}

/// Manifeste d'un pack d'assets sonores embarqué dans le bundle.
///
/// Ce fichier est le seul point de couplage entre l'application et un pack produit
/// ailleurs (par exemple un pack Kenney CC0). Tant qu'aucun manifeste n'est livré,
/// l'application reste silencieuse sans dégrader une seule fonctionnalité.
struct AudioManifest: Decodable, Equatable, Sendable {
    struct Track: Decodable, Equatable, Sendable {
        /// Nom de fichier sans extension, tel que présent dans le bundle.
        let resource: String
        /// Extension du fichier : `caf`, `m4a`, `mp3`, `wav`…
        let fileExtension: String
        /// Gain relatif du morceau, appliqué par-dessus le volume de couche.
        let gain: Double?
        /// Bouclage. Les ambiances bouclent par défaut, les signatures non.
        let loops: Bool?
    }

    static let supportedVersion = 1
    static let resourceName = "audio-manifest"

    let version: Int
    let attribution: String?
    let license: String?
    let ambiences: [String: Track]
    let cues: [String: Track]

    enum Failure: Error, LocalizedError, Equatable {
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case let .unsupportedVersion(version):
                "Manifeste audio version \(version) non pris en charge (attendu : \(AudioManifest.supportedVersion))."
            }
        }
    }

    /// Charge le manifeste embarqué. Renvoie `nil` si aucun pack n'est livré — cas nominal
    /// tant que le pack d'assets n'a pas atterri. Une version inconnue échoue explicitement
    /// au lieu d'être interprétée au petit bonheur.
    static func bundled(in bundle: Bundle = .main) throws -> AudioManifest? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else { return nil }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> AudioManifest {
        let manifest = try JSONDecoder().decode(AudioManifest.self, from: data)
        guard manifest.version == supportedVersion else { throw Failure.unsupportedVersion(manifest.version) }
        return manifest
    }

    func track(for ambience: AudioAmbience) -> Track? { ambiences[ambience.rawValue] }
    func track(for cue: AudioCue) -> Track? { cues[cue.rawValue] }

    var isEmpty: Bool { ambiences.isEmpty && cues.isEmpty }
}

/// Frontière technique de la restitution sonore. L'application ne connaît que ce protocole ;
/// AVFoundation reste confiné à son implémentation.
@MainActor
protocol GameAudioEngine: AnyObject {
    /// Vrai si au moins un fichier jouable a été résolu : permet à l'interface d'annoncer
    /// honnêtement qu'aucune bande-son n'est installée.
    var hasPlayableAssets: Bool { get }
    func prepare(manifest: AudioManifest?)
    func apply(settings: AudioSettings)
    func setAmbience(_ ambience: AudioAmbience?)
    func play(_ cue: AudioCue)
    func stopAll()
}

/// Implémentation de repli : ne produit aucun son et ne touche à aucune ressource système.
/// Sert aux tests, aux aperçus et à tout contexte où l'audio n'a pas de sens.
@MainActor
final class SilentGameAudioEngine: GameAudioEngine {
    private(set) var currentAmbience: AudioAmbience?
    private(set) var playedCues: [AudioCue] = []
    private(set) var appliedSettings: AudioSettings = .default

    var hasPlayableAssets: Bool { false }
    func prepare(manifest: AudioManifest?) {}
    func apply(settings: AudioSettings) { appliedSettings = settings }
    func setAmbience(_ ambience: AudioAmbience?) { currentAmbience = ambience }
    func play(_ cue: AudioCue) { playedCues.append(cue) }
    func stopAll() { currentAmbience = nil }
}
