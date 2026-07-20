import SwiftUI

/// Aide intégrée par champ : présentation et accessibilité.
///
/// ## L'arbitrage de densité
///
/// L'administration est un formulaire dense — le panneau « Accueil & aide » aligne à lui
/// seul une vingtaine de contrôles. Poser sous chaque champ sa description **et** sa
/// contrainte ajoute deux à trois lignes par champ : en portrait sur iPhone, un panneau
/// qui tenait en deux écrans en demanderait six, et le formulaire cesserait d'être
/// utilisable pour devenir une notice à faire défiler.
///
/// L'aide est donc **repliée par défaut derrière un bouton ⓘ posé en fin de ligne**. Le
/// coût vertical ajouté est nul : le champ garde sa hauteur, seule la largeur perd la
/// cible tactile de 44 pt. L'affordance reste visible en permanence — ce n'est pas un
/// appui long, ni un geste à deviner — et le contenu s'ouvre en popover à côté du champ
/// qu'il décrit, y compris en compact grâce à `presentationCompactAdaptation(.popover)` :
/// une feuille modale plein écran ferait perdre de vue le champ dont on cherche le sens.
///
/// ## L'accessibilité prime sur cet arbitrage
///
/// Un lecteur d'écran ne « survole » pas un encart : si la description vivait uniquement
/// dans le popover, elle serait inatteignable sans détour. Le compromis visuel n'est donc
/// **pas** reconduit pour VoiceOver. La description et la contrainte sont posées en
/// `accessibilityHint` **du champ lui-même**, annoncées avec lui, et le bouton ⓘ est retiré
/// de l'arbre d'accessibilité : il n'ajoute aucun élément à parcourir et ne donne accès à
/// rien qui ne soit déjà dit. Un utilisateur VoiceOver entend toute l'aide sans ouvrir
/// quoi que ce soit ; un utilisateur voyant l'ouvre d'un appui.
///
/// ## Repli
///
/// Un chemin absent du catalogue — moteur plus ancien, champ nouveau côté client, route
/// refusée faute de `config.read` — rend le champ **inchangé** : ni bouton, ni encart vide,
/// ni texte inventé. C'est le seul repli honnête, le client n'étant pas l'auteur de ces
/// phrases.
struct FieldHelpModifier: ViewModifier {
    let descriptor: ConfigurationFieldDescriptor?
    @State private var isPresented = false

    func body(content: Content) -> some View {
        if let descriptor {
            HStack(alignment: .center, spacing: 6) {
                content
                    .accessibilityHint(Text(descriptor.spokenHint))
                Button { isPresented = true } label: {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(GenEngineTheme.amber)
                        .frame(width: HUDMetrics.minimumTarget, height: HUDMetrics.minimumTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // La description est déjà portée par le champ : ce bouton n'ajouterait
                // qu'un élément de plus à parcourir, sans rien apprendre.
                .accessibilityHidden(true)
                .popover(isPresented: $isPresented) {
                    FieldHelpCard(descriptor: descriptor)
                }
            }
        }
        else { content }
    }
}

/// Contenu du popover d'aide. Il montre ce que le moteur sert, dans cet ordre :
/// à quoi sert le champ, quelle règle le serveur applique, quelle valeur ressemble à
/// une valeur juste.
struct FieldHelpCard: View {
    let descriptor: ConfigurationFieldDescriptor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(descriptor.label)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(descriptor.description)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                if let constraint = descriptor.constraint?.nonEmpty {
                    Label(constraint, systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(GenEngineTheme.verdigris)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let example = descriptor.example.nonEmpty {
                    Label("Exemple : \(example)", systemImage: "text.quote")
                        .font(.caption)
                        .foregroundStyle(GenEngineTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(descriptor.path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(GenEngineTheme.secondaryText.opacity(0.7))
                    // Le chemin sert l'exploitant qui lit la documentation du moteur ;
                    // il n'apporte rien à l'oral.
                    .accessibilityHidden(true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(idealWidth: 320, maxHeight: 420)
        .presentationCompactAdaptation(.popover)
    }
}

private struct ConfigurationFieldCatalogKey: EnvironmentKey {
    static let defaultValue = ConfigurationFieldCatalog.empty
}

extension EnvironmentValues {
    /// Catalogue d'aide servi par le moteur, posé une fois à la racine d'un écran de
    /// paramétrage plutôt que passé de champ en champ.
    var configurationFieldCatalog: ConfigurationFieldCatalog {
        get { self[ConfigurationFieldCatalogKey.self] }
        set { self[ConfigurationFieldCatalogKey.self] = newValue }
    }
}

/// Lit le catalogue d'environnement pour un chemin donné, puis applique `FieldHelpModifier`.
private struct CatalogFieldHelpModifier: ViewModifier {
    let path: String
    @Environment(\.configurationFieldCatalog) private var catalog

    func body(content: Content) -> some View {
        content.modifier(FieldHelpModifier(descriptor: catalog[path]))
    }
}

extension View {
    /// Attache l'aide servie pour ce chemin de champ. Sans descripteur, le champ est rendu
    /// tel quel.
    func fieldHelp(_ path: String) -> some View {
        modifier(CatalogFieldHelpModifier(path: path))
    }

    /// Variante pour un champ **qui n'appartient pas au document de configuration** —
    /// l'adressage des services, réglé sur l'appareil, que le moteur ne décrit pas et
    /// ne peut pas décrire. Même présentation, même contrat d'accessibilité, texte local
    /// assumé comme tel.
    func fieldHelp(local descriptor: ConfigurationFieldDescriptor) -> some View {
        modifier(FieldHelpModifier(descriptor: descriptor))
    }
}
