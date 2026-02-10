import SwiftUI

@main
struct ContainerManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Container Manager Help") {
                    // TODO: Open help documentation
                }
            }
        }
    }
}
