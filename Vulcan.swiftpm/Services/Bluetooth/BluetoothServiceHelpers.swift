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
    
    init?(_ services: [CBService]) {
        var service1: CBService?
        var service2: CBService?
        for service in services {
            switch service.uuid {
            case BLEServices.service1UUID:
                service1 = service
            case BLEServices.service2UUID:
                service2 = service
            default:
                continue
            }
        }
        guard let service1,
              let service2 else {
            return nil
        }
        self.service1 = service1
        self.service2 = service2
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
    
    init?(_ characteristics: [CBCharacteristic]) {
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
            case BLECharacteristics.firmwareCharUUID:
                firmwareChar = char
            case BLECharacteristics.serialCharUUID:
                serialChar = char
            case BLECharacteristics.modelCharUUID:
                modelChar = char
            case BLECharacteristics.currTempCharUUID:
                currTempChar = char
            case BLECharacteristics.targTempCharUUID:
                targTempChar = char
            case BLECharacteristics.isHeatAirEnabledCharUUID:
                isHeatAirEnabledChar = char
            case BLECharacteristics.startHeatCharUUID:
                startHeatChar = char
            case BLECharacteristics.stopHeatCharUUID:
                stopHeatChar = char
            case BLECharacteristics.startAirCharUUID:
                startAirChar = char
            case BLECharacteristics.stopAirCharUUID:
                stopAirChar = char
            default:
                continue
            }
        }
        guard let firmwareChar,
              let serialChar,
              let modelChar,
              let currTempChar,
              let targTempChar,
              let isHeatAirEnabledChar,
              let startHeatChar,
              let stopHeatChar,
              let startAirChar,
              let stopAirChar else {
            return nil
        }
        self.firmwareChar = firmwareChar
        self.serialChar = serialChar
        self.modelChar = modelChar
        self.currTempChar = currTempChar
        self.targTempChar = targTempChar
        self.isHeatAirEnabledChar = isHeatAirEnabledChar
        self.startHeatChar = startHeatChar
        self.stopHeatChar = stopHeatChar
        self.startAirChar = startAirChar
        self.stopAirChar = stopAirChar
    }
}
