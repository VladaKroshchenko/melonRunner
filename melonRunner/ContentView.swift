import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MenuViewControllerRepresentable()
                .tabItem {
                    Label("Menu", systemImage: "list.dash")
                }

            RunningView()
                .tabItem {
                    Label("Running", systemImage: "figure.walk")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
