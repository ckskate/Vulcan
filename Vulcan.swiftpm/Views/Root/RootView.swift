//
//  ContentView.swift
//  Shared
//
//  Created by Connor Killion on 8/23/21.
//

import SwiftUI

struct RootView: View {
    
    @StateObject var viewModel: ContentViewModel = ContentViewModel()
    
    @Service(\.volcanoManager) var volcanoManager: VolcanoManager
    @Environment(\.scenePhase) private var scenePhase: ScenePhase
    @State private var isAnimating: Bool = false
    
    private var showScanner: Binding<Bool> {
        Binding {
            self.volcanoManager.state == .disconnected
        } set: { _ in
            // nop
        }
    }
    
    private var showErrorAlert: Binding<Bool> {
        Binding {
            return self.volcanoManager.state.error != nil
        } set: { _ in
            // nop
        }
    }
    
    var body: some View {
        TabView {
            VolcanoControllerView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .fullScreenCover(isPresented: self.showScanner) {
            ScannerView(animationLength: ProductionBluetoothService.scanLength,
                        isAnimating: self.$isAnimating)
//            .opacity(self.viewModel.isConnected ? 0.0 : 1.0)
//            .animation(.interactiveSpring(), value: self.viewModel.isConnected)
//            .ignoresSafeArea()
        }
        .alert(isPresented: self.showErrorAlert, error: self.volcanoManager.state.error) {
            Button {
                // nop
            } label: {
                Text("Disconnect")
            }
        }
        .onChange(of: self.isAnimating) { newValue in
            guard newValue else {
                return
            }
//            self.viewModel.startConnectionTrackingLoop()
        }
    }
}
