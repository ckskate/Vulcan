import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    
    @Service(\.bluetoothService) private var bluetoothService
    
    private var backgroundConnectionTask: Task<Void, Never>?
    
    @Published var isConnected: Bool = false
    
    func startConnectionTrackingLoop() {
        guard self.backgroundConnectionTask == nil else {
            return
        }
        self.backgroundConnectionTask = Task.detached {
            await self.deviceConnectionLoop()
        }
    }
    
    func stopBackgroundLoopAndDisconnect() {
        self.backgroundConnectionTask?.cancel()
        self.backgroundConnectionTask = nil
    }
    
    func deviceConnectionLoop() async {
        while true {
            guard Task.isCancelled == false else {
                await self.bluetoothService.disconnectIfNeeded()
                self.isConnected = false
                return
            }
            
            guard await self.bluetoothService.isConnectedAndReady == false else {
                self.isConnected = true
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                continue
            }
            
            print("tyme to discover")
            let connectionResult = await self.bluetoothService.discoverAndConnectIfAvailable()
            
            if case .success = connectionResult {
                self.isConnected = true
            } else {
                self.isConnected = false
            }
        }
    }
}
