import SwiftUI
import CoreBluetooth

public extension Notification.Name {
    static let deviceDiscovered = Self("deviceDiscovered")
    static let deviceConnected = Self("deviceConnected")
    static let servicesDiscovered = Self("servicesDiscovered")
    static let charsDiscovered = Self("charsDiscovered")
    static let charRead = Self("charRead")
}

public extension Notification {
    static func deviceDiscovered(_ device: CBPeripheral) -> Notification {
        return Notification(name: .deviceDiscovered, object: nil, userInfo: ["device": device])
    }
    
    static func deviceConnected() -> Notification {
        return Notification(name: .deviceConnected, object: nil, userInfo: nil)
    }
    
    static func servicesDiscovered(_ services: [CBService]) -> Notification {
        return Notification(name: .servicesDiscovered, object: nil, userInfo: ["services": services])
    }
    
    static func charsDiscovered(_ chars: [CBCharacteristic], for service: CBService) -> Notification {
        return Notification(name: .charsDiscovered, 
                            object: nil, 
                            userInfo: ["chars": chars, 
                                       "service": service])
    }
    
    static func charRead(_ char: CBCharacteristic, data: Data) -> Notification {
        return Notification(name: .charRead, 
                            object: nil, 
                            userInfo: ["char": char, 
                                       "data": data])
    }
}
