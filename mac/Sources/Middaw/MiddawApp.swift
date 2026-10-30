import SwiftUI
import MiddawCore

@main
struct MiddawApp: App {
    var body: some Scene {
        WindowGroup {
            Text(Middaw.name)
                .frame(minWidth: 800, minHeight: 500)
        }
    }
}
