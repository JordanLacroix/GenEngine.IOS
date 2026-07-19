import SwiftUI

/// Métriques du HUD. Les vues de contenu s'en servent pour dégager la zone occupée par
/// la surcouche sans que celle-ci réserve de la place : le décor court bord à bord et le
/// contenu défilant s'arrête proprement sous le HUD.
enum HUDMetrics {
    static let topBarHeight: CGFloat = 74
    static let bottomBarHeight: CGFloat = 96
    static let railWidth: CGFloat = 108
    /// Cible tactile minimale imposée par l'accessibilité.
    static let minimumTarget: CGFloat = 44
}

/// Fond de HUD : verre translucide, contour discret, jamais opaque au point de cacher le décor.
struct HUDSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = 26

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(GenEngineTheme.ivory.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
    }
}

/// Surface de la barre haute du HUD.
///
/// Contrairement aux autres surfaces du HUD, celle-ci ne flotte pas : son matériau remonte
/// jusqu'au bord physique de l'écran et couvre donc la zone d'état. Une barre flottante,
/// posée sous l'encoche avec une marge, laisse le contenu défilant réapparaître en clair à
/// côté de l'horloge : le HUD est bien au-dessus du contenu, mais plus rien ne le voile
/// au-dessus de la barre. Le contenu passe désormais dessous, voilé de bout en bout.
struct HUDTopBarSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .top)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(GenEngineTheme.ivory.opacity(0.16))
                            .frame(height: 1)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            }
    }
}

extension View {
    func hudSurface(cornerRadius: CGFloat = 26) -> some View { modifier(HUDSurfaceModifier(cornerRadius: cornerRadius)) }

    /// Barre haute ancrée au bord de l'écran, voilant la zone d'état.
    func hudTopBarSurface() -> some View { modifier(HUDTopBarSurfaceModifier()) }
}

/// Bouton du HUD. Toujours au moins 44×44 points, toujours doté d'un libellé lisible par
/// VoiceOver même lorsque seul le symbole est affiché.
struct HUDButton: View {
    let symbol: String
    let title: String
    var showsTitle = false
    var isSelected = false
    var tint: Color = GenEngineTheme.ivory
    var hint: String?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Group {
                if showsTitle {
                    VStack(spacing: 4) {
                        Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                        Text(title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 10)
                } else {
                    Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                }
            }
            .frame(minWidth: HUDMetrics.minimumTarget, minHeight: HUDMetrics.minimumTarget)
            .foregroundStyle(isSelected ? GenEngineTheme.amber : tint)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(GenEngineTheme.amber.opacity(0.18))
                        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(GenEngineTheme.amber.opacity(0.55)) }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isSelected)
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Étiquette d'état du HUD : couleur *et* symbole *et* texte, jamais la couleur seule.
struct HUDBadge: View {
    let symbol: String
    let text: String
    var tint: Color = GenEngineTheme.verdigris

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            // La barre haute est étroite : une étiquette qui se replie sur trois lignes
            // écrase le nom de l'application à côté d'elle. Elle tient sur une ligne et
            // conserve sa largeur naturelle — c'est le nom de l'application, plus long et
            // déjà limité à une ligne, qui cède en premier.
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(tint.opacity(0.14), in: Capsule())
            .overlay { Capsule().stroke(tint.opacity(0.45)) }
    }
}

/// Panneau de HUD : un menu superposé au jeu plutôt qu'un écran de formulaire.
/// Le fond assombri est décoratif et masqué à VoiceOver ; le panneau lui-même est déclaré
/// modal uniquement lorsqu'il l'est réellement, afin de ne pas piéger le focus.
struct HUDOverlayPanel<Content: View>: View {
    let title: String
    var symbol: String = "square.stack.3d.up.fill"
    var isModal = true
    /// Un panneau qui porte une saisie en cours ne se referme pas sur un geste manqué :
    /// viser le clavier et perdre six adresses saisies n'est pas un compromis acceptable.
    /// La croix, elle, reste toujours disponible et explicitement libellée.
    var dismissesOnBackgroundTap = true
    let onClose: () -> Void
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            Color.black.opacity(0.66)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .onTapGesture { if dismissesOnBackgroundTap { onClose() } }
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Label(title, systemImage: symbol)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(GenEngineTheme.ivory)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    HUDButton(symbol: "xmark", title: "Fermer \(title)", tint: GenEngineTheme.ivory, action: onClose)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                Divider().overlay(GenEngineTheme.ivory.opacity(0.14))
                ScrollView { content.padding(20) }
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 760 : .infinity)
            .frame(maxHeight: .infinity)
            .hudSurface(cornerRadius: 30)
            .padding(horizontalSizeClass == .regular ? 40 : 12)
            .padding(.vertical, 24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isModal ? .isModal : [])
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
    }
}
