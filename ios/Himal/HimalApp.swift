import SwiftUI

@main
struct HimalApp: App {
    @State private var store = PanoramaStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
