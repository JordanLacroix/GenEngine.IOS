import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationStack {
            Group {
                if state.hasProductAccess { ProductShell() }
                else { WelcomeView() }
            }
            .navigationDestination(isPresented: Binding(
                get: { state.session != nil },
                set: { if !$0 { state.endSession() } }
            )) {
                PlayerView()
                    .navigationBarBackButtonHidden()
            }
        }
        .tint(GenEngineTheme.amber)
        .alert(state.gameName, isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button(state.copy("action.close", fallback: "Fermer"), role: .cancel) { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
    }
}

private struct ProductShell: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        TabView(selection: $state.selectedTab) {
            HomeView()
                .tabItem { Label(state.copy("nav.home", fallback: "Accueil"), systemImage: "sparkles") }
                .tag(AppTab.home)
            LibraryView()
                .tabItem { Label(state.copy("nav.library", fallback: "Bibliothèque"), systemImage: "books.vertical.fill") }
                .tag(AppTab.library)
            if state.hasPermission("session.play") {
                PlayerExperienceViewScreen()
                    .tabItem { Label(state.copy("nav.experience", fallback: "Mon univers"), systemImage: "wand.and.stars") }
                    .tag(AppTab.experience)
            }
            if state.hasPermission("scenario.author") {
                StudioView()
                    .tabItem { Label(state.copy("nav.studio", fallback: "Studio"), systemImage: "pencil.and.outline") }
                    .tag(AppTab.studio)
            }
            if state.hasPermission("config.read") {
                AdministrationView()
                    .tabItem { Label(state.copy("nav.administration", fallback: "Administration"), systemImage: "slider.horizontal.3") }
                    .tag(AppTab.administration)
            }
            AccountView()
                .tabItem { Label(state.isAuthenticated ? state.copy("nav.account", fallback: "Compte") : "Se connecter", systemImage: state.isAuthenticated ? "person.crop.circle.fill" : "key.fill") }
                .tag(AppTab.account)
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbar(state.selectedTab == .experience ? .hidden : .visible, for: .tabBar)
        .toolbar {
            if state.isAuthenticated { ToolbarItem(placement: .topBarTrailing) {
                Button { state.selectedTab = .account } label: {
                    Label(state.access?.userName ?? "Compte", systemImage: "person.crop.circle.fill.badge.checkmark")
                }
                .accessibilityHint("Gérer le compte et se déconnecter")
            } }
        }
    }
}
