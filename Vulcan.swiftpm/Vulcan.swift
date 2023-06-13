import SwiftUI

@main
struct Vulcan: App {
    @State var isDebugMode: Bool = false
    @Environment(\.scenePhase) private var scenePhase: ScenePhase
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: self.scenePhase) { newScenePhase in
            switch newScenePhase {
            case .active:
                // reset the animation state
                print("foregrounding")
//                if self.isAnimating {
//                    self.viewModel.startConnectionTrackingLoop()
//                }
            default:
                print("backgrounding")
//                self.viewModel.stopBackgroundLoopAndDisconnect()
            }
        }
    }
}

extension EnvironmentValues {
    var backgroundColor: Color { self.colorScheme == .dark ? .black : .white }
}
