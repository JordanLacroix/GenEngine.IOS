import Foundation
import Observation

/// Chef d'orchestre sonore de l'application.
///
/// Il possède les réglages persistés, décide de l'ambiance du lieu courant et déclenche
/// les signatures. Il ne connaît qu'un `GameAudioEngine` : la dépendance reste derrière
/// un protocole et le moteur silencieux suffit aux tests.
///
/// Deux garanties tenues ici :
/// 1. l'audio est coupable en permanence, et la coupure est immédiate ;
/// 2. aucun signal n'est le seul porteur d'une information — chaque appel double un
///    retour visuel déjà rendu par la vue appelante.
@MainActor
@Observable
final class GameAudioDirector {
    private let engine: any GameAudioEngine
    private let defaults: UserDefaults
    private static let settingsKey = "genengine.audio.settings.v1"

    /// Diagnostic de chargement du pack, sans jamais masquer un manifeste invalide.
    private(set) var manifestStatus: String

    var settings: AudioSettings {
        didSet {
            guard settings != oldValue else { return }
            persist()
            engine.apply(settings: settings)
            if settings.isEnabled { engine.setAmbience(ambience) } else { engine.setAmbience(nil) }
        }
    }

    private(set) var ambience: AudioAmbience?

    init(engine: (any GameAudioEngine)? = nil, defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        let engine = engine ?? BundledGameAudioEngine(bundle: bundle)
        self.engine = engine
        self.defaults = defaults
        self.settings = Self.loadSettings(from: defaults)
        var status: String
        do {
            if let manifest = try AudioManifest.bundled(in: bundle) {
                engine.prepare(manifest: manifest)
                status = manifest.isEmpty
                    ? "Manifeste audio vide : aucune piste déclarée."
                    : "Pack audio chargé (\(manifest.ambiences.count) ambiance(s), \(manifest.cues.count) signature(s))."
            } else {
                engine.prepare(manifest: nil)
                status = "Aucun pack audio installé : l’application reste silencieuse."
            }
        } catch {
            engine.prepare(manifest: nil)
            status = "Manifeste audio refusé : \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)"
        }
        self.manifestStatus = status
        engine.apply(settings: settings)
    }

    /// Vrai seulement si un fichier jouable existe réellement. L'interface s'en sert pour
    /// annoncer l'absence de bande-son plutôt que de laisser croire à une panne.
    var hasPlayableAssets: Bool { engine.hasPlayableAssets }

    var isEnabled: Bool {
        get { settings.isEnabled }
        set { settings.isEnabled = newValue }
    }

    /// Entrée dans un lieu de l'application. Idempotent : rappeler la même ambiance ne
    /// relance pas la boucle.
    func enter(_ ambience: AudioAmbience?) {
        guard self.ambience != ambience else { return }
        self.ambience = ambience
        guard settings.isEnabled else { return }
        engine.setAmbience(ambience)
    }

    /// Signature ponctuelle. À n'appeler que là où un retour visuel équivalent existe déjà.
    func signal(_ cue: AudioCue) {
        guard settings.isEnabled else { return }
        engine.play(cue)
    }

    func volume(for layer: AudioLayer) -> Double {
        switch layer {
        case .ambience: settings.ambienceVolume
        case .music: settings.musicVolume
        case .effects: settings.effectsVolume
        }
    }

    func setVolume(_ value: Double, for layer: AudioLayer) {
        settings.setVolume(value, for: layer)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.settingsKey)
    }

    private static func loadSettings(from defaults: UserDefaults) -> AudioSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AudioSettings.self, from: data)
        else { return .default }
        return settings
    }
}
