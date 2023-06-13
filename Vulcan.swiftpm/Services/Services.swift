import Foundation
import SwiftUI

final class Services: ObservableObject {
    static let shared = Services()
    
    private(set) var bluetoothService: BluetoothService = ProductionBluetoothService()
    @MainActor
    private(set) var volcanoManager: VolcanoManager = VolcanoManager()
    
    private init() { }
    
    @MainActor
    func resetServices() {
        self.objectWillChange.send()
        self.bluetoothService = ProductionBluetoothService()
        self.volcanoManager = VolcanoManager()
    }
}

@propertyWrapper
struct Service<T>: DynamicProperty {
    @ObservedObject private var services: Services
    private let keyPath: KeyPath<Services, T>
    
    init(_ keyPath: KeyPath<Services, T>, services: Services = .shared) {
        self._services = ObservedObject(wrappedValue: services)
        self.keyPath = keyPath
    }
    
    var wrappedValue: T {
        return self.services[keyPath: self.keyPath]
    }
}
