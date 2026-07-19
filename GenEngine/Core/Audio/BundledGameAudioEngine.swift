import AVFoundation
import Foundation

/// Restitution locale d'un pack d'assets embarqué.
///
/// Le moteur ne connaît que le manifeste : il ne code en dur aucun nom de fichier.
/// Si aucun pack n'est livré, ou si un fichier annoncé est absent, il reste silencieux
/// sans jamais empêcher une action. Aucune information n'est portée par le son seul :
/// chaque signature double un retour visuel déjà présent à l'écran.
@MainActor
final class BundledGameAudioEngine: GameAudioEngine {
    private let bundle: Bundle
    private var manifest: AudioManifest?
    private var settings: AudioSettings = .default
    private var ambiencePlayer: AVAudioPlayer?
    private var musicPlayer: AVAudioPlayer?
    private var effectPlayers: [AudioCue: AVAudioPlayer] = [:]
    private var currentAmbience: AudioAmbience?
    private var hasActivatedSession = false

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var hasPlayableAssets: Bool {
        guard let manifest else { return false }
        let ambiences = AudioAmbience.allCases.contains { manifest.track(for: $0).flatMap(url(for:)) != nil }
        let cues = AudioCue.allCases.contains { manifest.track(for: $0).flatMap(url(for:)) != nil }
        return ambiences || cues
    }

    func prepare(manifest: AudioManifest?) {
        self.manifest = manifest
        if let ambience = currentAmbience { setAmbience(ambience) }
    }

    func apply(settings: AudioSettings) {
        self.settings = settings
        ambiencePlayer?.volume = Float(settings.volume(for: .ambience))
        musicPlayer?.volume = Float(settings.volume(for: .music))
        for (cue, player) in effectPlayers { player.volume = Float(settings.volume(for: cue.layer)) }
        if !settings.isEnabled { stopAll() }
    }

    func setAmbience(_ ambience: AudioAmbience?) {
        guard currentAmbience != ambience || ambiencePlayer == nil else { return }
        currentAmbience = ambience
        ambiencePlayer?.stop()
        ambiencePlayer = nil
        guard settings.isEnabled, let ambience, let track = manifest?.track(for: ambience), let url = url(for: track) else { return }
        guard let player = makePlayer(url: url, layer: .ambience, gain: track.gain) else { return }
        player.numberOfLoops = (track.loops ?? true) ? -1 : 0
        activateSessionIfNeeded()
        player.play()
        ambiencePlayer = player
    }

    func play(_ cue: AudioCue) {
        guard settings.isEnabled, let track = manifest?.track(for: cue), let url = url(for: track) else { return }
        switch cue.layer {
        case .music:
            musicPlayer?.stop()
            guard let player = makePlayer(url: url, layer: .music, gain: track.gain) else { return }
            player.numberOfLoops = (track.loops ?? false) ? -1 : 0
            activateSessionIfNeeded()
            player.play()
            musicPlayer = player
        case .ambience, .effects:
            let player = effectPlayers[cue] ?? makePlayer(url: url, layer: cue.layer, gain: track.gain)
            guard let player else { return }
            player.volume = Float(settings.volume(for: cue.layer)) * Float(track.gain ?? 1)
            effectPlayers[cue] = player
            activateSessionIfNeeded()
            player.currentTime = 0
            player.play()
        }
    }

    func stopAll() {
        ambiencePlayer?.stop()
        ambiencePlayer = nil
        musicPlayer?.stop()
        musicPlayer = nil
        for player in effectPlayers.values { player.stop() }
        deactivateSession()
    }

    private func url(for track: AudioManifest.Track) -> URL? {
        bundle.url(forResource: track.resource, withExtension: track.fileExtension)
    }

    private func makePlayer(url: URL, layer: AudioLayer, gain: Double?) -> AVAudioPlayer? {
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.volume = Float(settings.volume(for: layer)) * Float(gain ?? 1)
        player.prepareToPlay()
        return player
    }

    /// La catégorie `ambient` garantit que l'application ne coupe jamais la musique
    /// que le joueur écoute déjà et respecte le commutateur silencieux.
    private func activateSessionIfNeeded() {
        guard !hasActivatedSession else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        hasActivatedSession = true
    }

    private func deactivateSession() {
        guard hasActivatedSession else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        hasActivatedSession = false
    }
}
