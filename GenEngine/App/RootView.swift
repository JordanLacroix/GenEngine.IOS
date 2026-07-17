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
        .alert("GenEngine", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("Fermer", role: .cancel) { state.errorMessage = nil }
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
                .tabItem { Label("Accueil", systemImage: "sparkles") }
                .tag(AppTab.home)
            LibraryView()
                .tabItem { Label("Bibliothèque", systemImage: "books.vertical.fill") }
                .tag(AppTab.library)
            #if DEBUG
            DeveloperView()
                .tabItem { Label("Developer", systemImage: "hammer.fill") }
                .tag(AppTab.developer)
            #endif
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }
}
