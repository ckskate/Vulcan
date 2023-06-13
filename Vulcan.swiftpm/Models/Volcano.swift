import Foundation
import CoreBluetooth

struct Volcano: Identifiable {
    let name: String?
    let id: UUID
    let peripheral: CBPeripheral
    
    fileprivate init(name: String,
                     id: UUID,
                     peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.name = peripheral.name
        self.id = peripheral.identifier
    }
}

extension CBPeripheral {
    var asVolcano: Volcano? {
        guard let name,
              name.contains("VOLCANO") else {
            return nil
        }
        return Volcano(name: name,
                       id: self.identifier,
                       peripheral: self)
    }
}
