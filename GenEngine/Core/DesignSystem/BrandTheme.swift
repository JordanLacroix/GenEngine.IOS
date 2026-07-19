import SwiftUI
import Observation

#if canImport(UIKit)
import UIKit
#endif

/// Palette effective de l'application.
///
/// Les valeurs par défaut sont celles historiquement codées dans `GenEngineTheme` : elles
/// restent le **repli** documenté lorsque `GET /client-bootstrap/{frontId}` est injoignable.
/// Dès que le moteur répond, `branding.theme.colors` et `branding.accentPalette` les
/// remplacent, et les jetons d'accent nommés portés par les catégories, parcours et
/// familiers (`or`, `azur`, `encre`, `sauge`…) deviennent rendables.
struct BrandPalette: Sendable, Equatable {
    var ink: Color
    var midnight: Color
    var ivory: Color
    var ember: Color
    var amber: Color
    var verdigris: Color
    var violet: Color
    /// Jetons nommés servis par le moteur, indexés en minuscules.
    var accentTokens: [String: Color]

    static let fallback = BrandPalette(
        ink: Color(red: 0.025, green: 0.035, blue: 0.055),
        midnight: Color(red: 0.055, green: 0.075, blue: 0.11),
        ivory: Color(red: 0.96, green: 0.92, blue: 0.82),
        ember: Color(red: 0.94, green: 0.42, blue: 0.18),
        amber: Color(red: 0.96, green: 0.68, blue: 0.28),
        verdigris: Color(red: 0.25, green: 0.67, blue: 0.61),
        violet: Color(red: 0.53, green: 0.43, blue: 0.77),
        accentTokens: [:])

    /// Couleur d'un jeton d'accent nommé.
    ///
    /// Ordre de résolution : palette servie par le moteur, puis correspondance connue vers
    /// un rôle de la palette locale, puis `verdigris`. Un jeton inconnu ne fait donc jamais
    /// disparaître un élément : il retombe sur une couleur lisible.
    func accent(token: String) -> Color {
        let key = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let served = accentTokens[key] { return served }
        switch key {
        case "cuivre", "ember", "danger": return ember
        case "or", "amber", "gold", "warning": return amber
        case "aube", "violet", "dawn": return violet
        case "azur", "encre", "ink", "sauge", "success": return verdigris
        default: return verdigris
        }
    }
}

/// Porteur observable de la palette effective.
///
/// `GenEngineTheme` lit ses couleurs ici. Comme le type est `@Observable`, toute lecture
/// faite pendant l'évaluation d'un `body` SwiftUI enregistre une dépendance : appliquer la
/// palette servie par le moteur invalide les vues concernées sans qu'aucune d'elles ait à
/// déclarer explicitement une dépendance d'environnement.
@MainActor
@Observable
final class BrandTheme {
    static let shared = BrandTheme()

    private(set) var palette: BrandPalette = .fallback
    /// Vrai dès qu'une charte servie par le moteur a été appliquée. Utile pour dire
    /// honnêtement, en diagnostic, que l'on affiche encore le repli compilé.
    private(set) var isServed = false

    private init() {}

    /// Applique la charte servie par `GET /client-bootstrap/{frontId}`.
    ///
    /// Le client conserve délibérément son **substrat sombre** : le moteur publie
    /// `colorScheme = "Light"` avec une surface crème, destinée au client Web, alors que la
    /// coque iOS est une présentation immersive plein écran. Reprendre `surface` comme fond
    /// donnerait un texte crème sur crème. Sont donc repris du serveur : les accents, les
    /// jetons nommés, et la teinte d'encre qui devient la base du dégradé de fond.
    func apply(_ branding: ClientBrandingView?) {
        guard let branding else { return }
        var palette = BrandPalette.fallback
        let colors = branding.theme?.colors ?? [:]

        func color(_ key: String) -> Color? { colors[key].flatMap(Color.init(hexString:)) }

        if let accent = color("accent") { palette.amber = accent }
        if let surface = color("surface") { palette.ivory = surface }
        if let alternate = color("accentAlt") { palette.verdigris = alternate }
        if let danger = color("danger") { palette.ember = danger }
        if let warning = color("warning") { palette.ember = warning }

        var tokens: [String: Color] = [:]
        for (name, value) in branding.accentPalette ?? [:] {
            guard let parsed = Color(hexString: value) else { continue }
            tokens[name.lowercased()] = parsed
        }
        palette.accentTokens = tokens

        // Les jetons nommés priment sur les rôles génériques : ce sont eux que porte le
        // contenu, et c'est par eux que la charte se lit à l'écran.
        if let copper = tokens["cuivre"] { palette.ember = copper }
        if let gold = tokens["or"] { palette.amber = gold }
        if let dawn = tokens["aube"] { palette.violet = dawn }
        if let azure = tokens["azur"] { palette.verdigris = azure }

        // Le fond reste sombre : l'encre servie est assombrie plutôt qu'utilisée telle quelle.
        if let ink = tokens["encre"] ?? color("ink") {
            palette.ink = ink.darkened(by: 0.62)
            palette.midnight = ink.darkened(by: 0.28)
        }

        self.palette = palette
        isServed = true
    }

    /// Remet le repli compilé. Réservé aux tests et à la déconnexion d'un front.
    func reset() {
        palette = .fallback
        isServed = false
    }
}

extension Color {
    /// Analyse `#rrggbb`, `#rrggbbaa`, `#rgb`. Rend `nil` sur toute autre forme plutôt que
    /// d'inventer une couleur : une charte illisible doit retomber sur le repli, pas sur du noir.
    init?(hexString: String) {
        var value = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        guard value.count == 6 || value.count == 8,
              value.allSatisfy(\.isHexDigit),
              let raw = UInt64(value, radix: 16) else { return nil }

        let hasAlpha = value.count == 8
        let red = Double((raw >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let green = Double((raw >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = Double((raw >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = hasAlpha ? Double(raw & 0xFF) / 255 : 1
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    /// Assombrit vers le noir. `amount` va de 0 (inchangé) à 1 (noir).
    func darkened(by amount: Double) -> Color {
        #if canImport(UIKit)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }
        let factor = 1 - max(0, min(1, amount))
        return Color(.sRGB, red: Double(red) * factor, green: Double(green) * factor, blue: Double(blue) * factor, opacity: Double(alpha))
        #else
        return self
        #endif
    }
}
