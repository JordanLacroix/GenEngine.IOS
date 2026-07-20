import Foundation
import Testing
@testable import GenEngine

struct GameAudioTests {
    private func manifestData(version: Int) -> Data {
        Data("""
        {
          "version": \(version),
          "attribution": "Kenney (CC0)",
          "license": "CC0-1.0",
          "ambiences": { "world": { "resource": "amb-world", "fileExtension": "m4a", "gain": 0.9, "loops": true } },
          "cues": { "choice": { "resource": "sfx-choice", "fileExtension": "m4a" } }
        }
        """.utf8)
    }

    @Test func manifestDecodesTracksByAmbienceAndCue() throws {
        let manifest = try AudioManifest.decode(manifestData(version: 1))
        #expect(manifest.track(for: .world)?.resource == "amb-world")
        #expect(manifest.track(for: .world)?.loops == true)
        #expect(manifest.track(for: .choice)?.fileExtension == "m4a")
        #expect(manifest.track(for: .administration) == nil)
        #expect(manifest.isEmpty == false)
    }

    /// Invariant 12 : un contrat inconnu échoue explicitement au lieu d'être interprété.
    @Test func manifestRejectsUnknownVersion() {
        #expect(throws: AudioManifest.Failure.unsupportedVersion(99)) {
            _ = try AudioManifest.decode(manifestData(version: 99))
        }
    }

    /// Aucun pack livré est un cas nominal : l'application reste silencieuse, pas en panne.
    @Test func missingManifestIsNotAFailure() throws {
        #expect(try AudioManifest.bundled(in: Bundle(for: ProbeAnchor.self)) == nil)
    }

    /// Le pack réellement embarqué doit se résoudre en fichiers présents.
    ///
    /// Le manifeste est du texte : une clé mal orthographiée ou un fichier renommé
    /// laisse l'application compiler et se lancer, simplement muette. Seule une
    /// vérification des URL attrape la régression.
    @Test func shippedManifestResolvesEveryDeclaredFile() throws {
        let bundle = Bundle.main
        guard let manifest = try AudioManifest.bundled(in: bundle) else { return }

        #expect(manifest.isEmpty == false)
        #expect(manifest.license?.isEmpty == false, "un pack distribué doit porter sa licence")

        // Le pack couvre les douze clés : une clé perdue rendrait un écran muet en
        // silence, sans que rien d'autre ne le signale.
        for ambience in AudioAmbience.allCases {
            let track = try #require(manifest.track(for: ambience), "ambiance \(ambience.rawValue) absente du manifeste")
            #expect(
                bundle.url(forResource: track.resource, withExtension: track.fileExtension) != nil,
                "ambiance \(ambience.rawValue) : \(track.resource).\(track.fileExtension) absent du bundle")
        }

        for cue in AudioCue.allCases {
            let track = try #require(manifest.track(for: cue), "signature \(cue.rawValue) absente du manifeste")
            #expect(
                bundle.url(forResource: track.resource, withExtension: track.fileExtension) != nil,
                "signature \(cue.rawValue) : \(track.resource).\(track.fileExtension) absent du bundle")
        }
    }

    @Test func disabledSettingsSilenceEveryLayer() {
        var settings = AudioSettings.default
        settings.setVolume(0.8, for: .ambience)
        #expect(settings.volume(for: .ambience) == 0.8)
        settings.isEnabled = false
        for layer in AudioLayer.allCases { #expect(settings.volume(for: layer) == 0) }
    }

    @Test func volumesStayInRange() {
        var settings = AudioSettings.default
        settings.setVolume(4.2, for: .music)
        settings.setVolume(-3, for: .effects)
        #expect(settings.musicVolume == 1)
        #expect(settings.effectsVolume == 0)
    }

    @Test func gameOverIsMusicAndSignalsAreEffects() {
        #expect(AudioCue.gameOver.layer == .music)
        for cue in [AudioCue.choice, .error, .reward] { #expect(cue.layer == .effects) }
    }

    @MainActor
    @Test func directorRoutesAmbienceAndCuesToTheEngine() {
        let engine = SilentGameAudioEngine()
        let director = GameAudioDirector(engine: engine, defaults: Self.isolatedDefaults(), bundle: Bundle(for: ProbeAnchor.self))
        director.enter(.library)
        #expect(engine.currentAmbience == .library)
        director.signal(.reward)
        #expect(engine.playedCues == [.reward])
    }

    /// Le son est coupable en permanence : une fois coupé, plus rien ne part vers le moteur.
    @MainActor
    @Test func disablingAudioStopsEveryEmission() {
        let engine = SilentGameAudioEngine()
        let director = GameAudioDirector(engine: engine, defaults: Self.isolatedDefaults(), bundle: Bundle(for: ProbeAnchor.self))
        director.enter(.world)
        director.isEnabled = false
        #expect(engine.currentAmbience == nil)
        director.signal(.error)
        #expect(engine.playedCues.isEmpty)
    }

    @MainActor
    @Test func settingsSurviveARestart() {
        let defaults = Self.isolatedDefaults()
        let first = GameAudioDirector(engine: SilentGameAudioEngine(), defaults: defaults, bundle: Bundle(for: ProbeAnchor.self))
        first.setVolume(0.31, for: .music)
        first.isEnabled = false
        let second = GameAudioDirector(engine: SilentGameAudioEngine(), defaults: defaults, bundle: Bundle(for: ProbeAnchor.self))
        #expect(second.settings.musicVolume == 0.31)
        #expect(second.isEnabled == false)
    }

    private static func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "genengine.tests.\(UUID().uuidString)") ?? .standard
    }
}

/// Ancre de bundle : le bundle de tests ne contient aucun manifeste audio.
private final class ProbeAnchor {}
