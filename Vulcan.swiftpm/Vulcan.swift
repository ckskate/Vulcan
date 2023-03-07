import SwiftUI

@main
struct Vulcan: App {
    
    @StateObject private var services = Services(isDebugMode: false)
    @State var isDebugMode: Bool = false
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: ContentViewModel(bluetoothService: self.services.bluetoothService))
                .environmentObject(self.services)
        }
    }
}
