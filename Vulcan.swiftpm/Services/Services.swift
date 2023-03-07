import Foundation

final class Services: ObservableObject {
    
    let bluetoothService: BluetoothService
    
    init(isDebugMode: Bool) {
        self.bluetoothService = ProductionBluetoothService()
    }
}
