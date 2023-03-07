//
//  ContentView.swift
//  Shared
//
//  Created by Connor Killion on 8/23/21.
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject private var services: Services
    
    @StateObject var viewModel: ContentViewModel
    
    @Environment(\.scenePhase) private var scenePhase: ScenePhase
    @State private var isAnimating: Bool = false
    
    var body: some View {
        ZStack {
            TabView {
                VolcanoControllerView(viewModel: VolcanoControllerViewModel(bluetoothService: self.services.bluetoothService))
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                
                Text("cumming soon!")
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            
            ScannerView(isAnimating: self.$isAnimating)
                .opacity(self.viewModel.isConnected ? 0.0 : 1.0)
                .animation(.interactiveSpring(), value: self.viewModel.isConnected)
        }
        .onChange(of: self.scenePhase) { newScenePhase in
            switch newScenePhase {
            case .active:
                // reset the animation state
                print("foregrounding")
                if self.isAnimating {
                    self.viewModel.startConnectionTrackingLoop()
                }
            default:
                print("backgrounding")
                self.viewModel.stopBackgroundLoopAndDisconnect()
            }
        }
        .onChange(of: self.isAnimating) { newValue in
            guard newValue else {
                return
            }
            self.viewModel.startConnectionTrackingLoop()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static let services = Services(isDebugMode: true)
    
    static var previews: some View {
        ContentView(viewModel: ContentViewModel(bluetoothService: self.services.bluetoothService))
            .environmentObject(services)
    }
}
