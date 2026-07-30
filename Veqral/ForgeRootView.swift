import SwiftUI

enum ForgeTab: Hashable {
    case missions
    case attention
    case connection
}

struct ForgeRootView: View {
    @EnvironmentObject private var store: ForgeStore
    @State private var selectedTab: ForgeTab = .missions
    @State private var showsNewTask = false
    @State private var startupError: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ForgeMissionListView(showsNewTask: $showsNewTask)
            }
            .tabItem { Label("ミッション", systemImage: "scope") }
            .tag(ForgeTab.missions)

            NavigationStack {
                ForgeAttentionQueueView()
            }
            .tabItem { Label("要対応", systemImage: "person.crop.circle.badge.exclamationmark") }
            .badge(store.projection.attention.count)
            .tag(ForgeTab.attention)

            NavigationStack {
                ForgeConnectionView()
            }
            .tabItem { Label("接続", systemImage: "macbook.and.iphone") }
            .tag(ForgeTab.connection)
        }
        .tint(ForgeTheme.accent)
        .task {
            guard store.host != nil else { return }
            do {
                try await store.refresh()
            } catch {
                startupError = error.localizedDescription
            }
        }
        .sheet(isPresented: $showsNewTask) {
            ForgeNewTaskView()
                .environmentObject(store)
        }
        .alert("接続を確認してください", isPresented: errorBinding) {
            Button("閉じる") { startupError = nil }
        } message: {
            Text(startupError ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { startupError != nil },
            set: { if !$0 { startupError = nil } }
        )
    }
}
