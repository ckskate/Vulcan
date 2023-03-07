import SwiftUI
import CoreBluetooth

struct BLEServices {
    static let service1UUID = CBUUID(string: "10100000-5354-4f52-5a26-4249434b454c")
    static let service2UUID = CBUUID(string: "10110000-5354-4f52-5a26-4249434b454c")
    
    static var allUUIDS: [CBUUID] {
        return [service1UUID, service2UUID]
    }
    
    let service1: CBService
    let service2: CBService
    
    var allServices: [CBService] {
        return [self.service1, self.service2]
    }
    
    static func from(_ services: [CBService]) -> BLEServices? {
        var service1: CBService? = nil
        var service2: CBService? = nil
        for service in services {
            switch service.uuid {
            case service1UUID:
                service1 = service
            case service2UUID:
                service2 = service
            default:
                continue
            }
        }
        guard let service1 = service1,
              let service2 = service2 else {
            return nil
        }
        return BLEServices(service1: service1, service2: service2)
    }
}

struct BLECharacteristics {
    static let firmwareCharUUID = CBUUID(string: "10100005-5354-4f52-5a26-4249434b454c")
    static let serialCharUUID = CBUUID(string: "10100008-5354-4f52-5a26-4249434b454c")
    static let modelCharUUID = CBUUID(string: "10100007-5354-4f52-5a26-4249434b454c")
    static let currTempCharUUID = CBUUID(string: "10110001-5354-4f52-5a26-4249434b454c")
    static let targTempCharUUID = CBUUID(string: "10110003-5354-4f52-5a26-4249434b454c")
    static let isHeatAirEnabledCharUUID = CBUUID(string: "1010000c-5354-4f52-5a26-4249434b454c")
    static let startHeatCharUUID = CBUUID(string: "1011000f-5354-4f52-5a26-4249434b454c")
    static let stopHeatCharUUID = CBUUID(string: "10110010-5354-4f52-5a26-4249434b454c")
    static let startAirCharUUID = CBUUID(string: "10110013-5354-4f52-5a26-4249434b454c")
    static let stopAirCharUUID = CBUUID(string: "10110014-5354-4f52-5a26-4249434b454c")
    
    static var service1CharUUIDs: [CBUUID] {
        return [firmwareCharUUID, 
                serialCharUUID, 
                modelCharUUID, 
                isHeatAirEnabledCharUUID]
    }
    
    static var service2CharUUIDs: [CBUUID] {
        return [currTempCharUUID, 
                targTempCharUUID, 
                startAirCharUUID, 
                stopAirCharUUID, 
                startHeatCharUUID, 
                stopHeatCharUUID]
    }
    
    let firmwareChar: CBCharacteristic
    let serialChar: CBCharacteristic
    let modelChar: CBCharacteristic
    let currTempChar: CBCharacteristic
    let targTempChar: CBCharacteristic
    let isHeatAirEnabledChar: CBCharacteristic
    let startHeatChar: CBCharacteristic
    let stopHeatChar: CBCharacteristic
    let startAirChar: CBCharacteristic
    let stopAirChar: CBCharacteristic
    
    static func from(_ characteristics: [CBCharacteristic]) -> BLECharacteristics? {
        var firmwareChar: CBCharacteristic?
        var serialChar: CBCharacteristic?
        var modelChar: CBCharacteristic?
        var currTempChar: CBCharacteristic?
        var targTempChar: CBCharacteristic?
        var isHeatAirEnabledChar: CBCharacteristic?
        var startHeatChar: CBCharacteristic?
        var stopHeatChar: CBCharacteristic?
        var startAirChar: CBCharacteristic?
        var stopAirChar: CBCharacteristic?
        for char in characteristics {
            switch char.uuid {
            case firmwareCharUUID:
                firmwareChar = char
            case serialCharUUID:
                serialChar = char
            case modelCharUUID:
                modelChar = char
            case currTempCharUUID:
                currTempChar = char
            case targTempCharUUID:
                targTempChar = char
            case isHeatAirEnabledCharUUID:
                isHeatAirEnabledChar = char
            case startHeatCharUUID:
                startHeatChar = char
            case stopHeatCharUUID:
                stopHeatChar = char
            case startAirCharUUID:
                startAirChar = char
            case stopAirCharUUID:
                stopAirChar = char
            default:
                continue
            }
        }
        guard let firmwareChar = firmwareChar,
              let serialChar = serialChar,
              let modelChar = modelChar,
              let currTempChar = currTempChar,
              let targTempChar = targTempChar,
              let isHeatAirEnabledChar = isHeatAirEnabledChar,
              let startHeatChar = startHeatChar,
              let stopHeatChar = stopHeatChar,
              let startAirChar = startAirChar,
              let stopAirChar = stopAirChar else {
            return nil
        }
        return BLECharacteristics(firmwareChar: firmwareChar, 
                                  serialChar: serialChar, 
                                  modelChar: modelChar, 
                                  currTempChar: currTempChar, 
                                  targTempChar: targTempChar, 
                                  isHeatAirEnabledChar: isHeatAirEnabledChar, 
                                  startHeatChar: startHeatChar, 
                                  stopHeatChar: stopHeatChar, 
                                  startAirChar: startAirChar, 
                                  stopAirChar: stopAirChar)
    }
}
