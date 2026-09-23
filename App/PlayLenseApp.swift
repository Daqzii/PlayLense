import SwiftUI
import PlayLenseCore
import PlayLenseData
import PlayLenseUI

@main
struct PlayLenseApp: App {
    @State private var model: AppModel?
    @State private var startupError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let m = model {
                    RootView(model: m)
                } else if let e = startupError {
                    ContentUnavailableView("Start fehlgeschlagen", systemImage: "exclamationmark.triangle", description: Text(e))
                } else {
                    ProgressView("PlayLense startet …")
                        .task {
                            do {
                                let m = try AppModel.live()
                                m.resumeRunningMatchIfAny()
                                model = m
                            } catch {
                                startupError = error.localizedDescription
                            }
                        }
                }
            }
        }
    }
}
