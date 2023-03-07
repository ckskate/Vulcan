//
//  CCBCentralManager.swift
//  CCBCentralManager
//
//  Created by Connor Killion on 9/12/21.
//

import Foundation
import CoreBluetooth

enum BluetoothError: Error {
    case deviceNotFound, unsupportedPlatform, permissionDenied
}

protocol BluetoothService: Actor {
    // device discovery/connection
    func discoverAndConnectIfAvailable() async -> Result<Void, BluetoothError>
    func disconnectIfNeeded() async
    
    var isConnectedAndReady: Bool { get }
    
    // getting/state
    func getCurrTemp() async -> Result<Temperature, BluetoothError>
    func getTargTemp() async -> Result<Temperature, BluetoothError>
    func getHeatAirState() async -> Result<HeatAirState, BluetoothError>
    func set(temp: Temperature) async
    func set(heatAirState: HeatAirState) async
}

actor ProductionBluetoothService: BluetoothService {
    
    private let centralManager = CBCentralManager()
    private let cBDelegate = BluetoothServiceCBDelegate()
    
    private var runningDeviceConnectionTask: Task<Result<Void, BluetoothError>, Never>?
    private var runningDeviceSearchTask: Task<Result<CBPeripheral, BluetoothError>, Never>?
    private var runningServiceSearchTask: Task<[CBService], Never>?
    private var runningCharacteristicSearchTask: Task<[CBCharacteristic], Never>?
    private var runningCharacteristicReadTasks: [CBCharacteristic: Task<Data?, Never>] = [:]
    
    private var volcano: CBPeripheral?
    private var chars: BLECharacteristics?
    private var services: BLEServices?
    
    private var currTemp: Temperature = .zero
    private var targTemp: Temperature = .zero
    private var currHeatAirState: HeatAirState = .allOff
    
    private var isCurrTempFreshlyWritten = false
    private var isTargTempFreshlyWritten = false
    private var isHeatAirFreshlyWritten = false
    
    public var isConnectedAndReady: Bool {
        return (self.volcano?.state ?? .none) == .connected
                && self.services != nil
                && self.chars != nil
    }

    init() {
        self.centralManager.delegate = self.cBDelegate
    }
    
    // MARK: Public device discovery/connection
    
    public func discoverAndConnectIfAvailable() async -> Result<Void, BluetoothError> {
        guard self.volcano == nil,
              self.volcano?.state != .connected else {
            return .success(())
        }
        // discover and store volcano
        let volcanoResult = await self.discoverVolcano()
        guard case let .success(volcano) = volcanoResult else {
            // we know it's the error case here, 
            // so just force the result types to match
            return volcanoResult.map { CBPeripheral -> Void in () }
        }
        volcano.delegate = self.cBDelegate
        self.volcano = volcano
        // connect
        if case let .failure(error) = await self.connectIfNeeded() {
            return .failure(error)
        }
        // discover and store required services and characteristics
        self.services = BLEServices.from(await self.discoverRequiredServices())
        self.chars = BLECharacteristics.from(await self.discoverRequiredCharacteristics())
        return .success(())
    }
    
    public func disconnectIfNeeded() async {
        guard let volcano = self.volcano,
              volcano.state == .connected else {
            return
        }
        print("disconnecting")
        self.volcano = nil
        self.centralManager.cancelPeripheralConnection(volcano)
    }
    
    // getting/setting state
    
    public func getCurrTemp() async -> Result<Temperature, BluetoothError> {
        guard let chars = self.chars else {
            fatalError("Need the characteristics")
        }
        
        let devCurrTemp: Data? = await withTaskGroup(of: Data?.self) { taskGroup in
            taskGroup.addTask {
                return await self.readValue(for: chars.currTempChar)
            }
            taskGroup.addTask {
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                return nil
            }
            for await result in taskGroup {
                taskGroup.cancelAll()
                return result
            }
            return nil
        }
        
        guard let devCurrTemp = devCurrTemp else {
            return .failure(.deviceNotFound)
        }
        
        guard self.isCurrTempFreshlyWritten == false else {
            self.isCurrTempFreshlyWritten = false
            return .success(self.currTemp)
        }
        self.currTemp = Temperature.from(data: devCurrTemp)
        return .success(self.currTemp)
    }
    
    public func getTargTemp() async -> Result<Temperature, BluetoothError> {
        guard let chars = self.chars else {
            fatalError("Need the characteristics")
        }
        
        let devTargTemp: Data? = await withTaskGroup(of: Data?.self) { taskGroup in
            taskGroup.addTask {
                return await self.readValue(for: chars.targTempChar)
            }
            taskGroup.addTask {
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                return nil
            }
            for await result in taskGroup {
                taskGroup.cancelAll()
                return result
            }
            return nil
        }
        
        guard let devTargTemp = devTargTemp else {
            return .failure(.deviceNotFound)
        }
        
        guard self.isTargTempFreshlyWritten == false else {
            self.isTargTempFreshlyWritten = false
            return .success(self.targTemp)
        }
        self.targTemp = Temperature.from(data: devTargTemp)
        return .success(self.targTemp)
    }
    
    public func set(temp: Temperature) async {
        guard let chars = self.chars else {
            fatalError("Need the characteristics")
        }
        self.isTargTempFreshlyWritten = true
        self.targTemp = temp
        await self.writeValue(temp.asData, for: chars.targTempChar)
    }
    
    public func getHeatAirState() async -> Result<HeatAirState, BluetoothError> {
        guard let chars = self.chars else {
            fatalError("Need the characteristics")
        }
        
        let devHeatAirState: Data? = await withTaskGroup(of: Data?.self) { taskGroup in
            taskGroup.addTask {
                return await self.readValue(for: chars.isHeatAirEnabledChar)
            }
            taskGroup.addTask {
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                return nil
            }
            for await result in taskGroup {
                taskGroup.cancelAll()
                return result
            }
            return nil
        }
        
        guard let devHeatAirState = devHeatAirState else {
            return .failure(.deviceNotFound)
        }
        
        guard self.isHeatAirFreshlyWritten == false else {
            self.isHeatAirFreshlyWritten = false
            return .success(self.currHeatAirState)
        }
        self.currHeatAirState = HeatAirState.from(data: devHeatAirState)
        return .success(self.currHeatAirState)
    }
    
    
    public func set(heatAirState: HeatAirState) async {
        guard let chars = self.chars else {
            fatalError("Need the characteristics")
        }
        self.isHeatAirFreshlyWritten = true
        self.currHeatAirState = heatAirState
        
        await withTaskGroup(of: Void.self) { taskGroup in
            switch heatAirState {
            case .allOff:
                taskGroup.addTask {
                    await self.writeValue(Data(repeating: 1, count: 1), for: chars.stopAirChar)
                }
                taskGroup.addTask {
                    await self.writeValue(Data(repeating: 1, count: 1), for: chars.stopHeatChar)
                }
            case .heatOn:
                taskGroup.addTask {
                    await self.writeValue(Data(repeating: 1, count: 1), for: chars.stopAirChar)
                }
                taskGroup.addTask {
                    await self.writeValue(Data(repeating: 1, count: 1), for: chars.startHeatChar)
                }
            case .heatAndAirOn:
                taskGroup.addTask {
                    await self.writeValue(Data(repeating: 1, count: 1), for: chars.startAirChar)
                }
                taskGroup.addTask {
                    await self.writeValue(Data(repeating: 1, count: 1), for: chars.startHeatChar)
                }
            }
        }
    }
    
    // MARK: Data transfer helpers
    
    private func readValue(for characteristic: CBCharacteristic) async -> Data? {
        defer {
            self.runningCharacteristicReadTasks.removeValue(forKey: characteristic)
        }
        
        guard self.runningCharacteristicReadTasks[characteristic] == nil else {
            return await self.runningCharacteristicReadTasks[characteristic]!.value
        }
        
        self.runningCharacteristicReadTasks[characteristic] = Task(priority: .userInitiated) {
            guard let volcano = self.volcano,
                  case .success = await self.prepareCentralManager(),
                  case .success = await self.connectIfNeeded() else {
                return nil
            }
            volcano.readValue(for: characteristic)
            let newValue = await NotificationCenter
                                    .default
                                    .notifications(named: .charRead)
                                    .first(where: { $0.userInfo?["char"] as? CBCharacteristic == characteristic })?
                                    .userInfo?["data"] as? Data
            return newValue
        }
        
        return await self.runningCharacteristicReadTasks[characteristic]!.value
    }
    
    private func writeValue(_ data: Data, for characteristic: CBCharacteristic) async {
        guard let volcano = self.volcano,
              case .success = await self.prepareCentralManager(),
              case .success = await self.connectIfNeeded() else {
            return
        }
        print(data)
        volcano.writeValue(data,
                           for: characteristic,
                           type: .withResponse)
    }
    
    // MARK: Discovery helpers
    
    private func prepareCentralManager() async -> Result<(), BluetoothError> {
        guard self.centralManager.state != .unsupported else {
            return .failure(.unsupportedPlatform)
        }
        
        guard self.centralManager.state != .unauthorized else {
            return .failure(.permissionDenied)
        }
        
        var attemptsLeft = 3
        while self.centralManager.state != .poweredOn,
              attemptsLeft > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            attemptsLeft -= 1
        }
        
        return self.centralManager.state == .poweredOn 
                ? .success(()) 
                : .failure(.deviceNotFound)
    }
    
    private func connectIfNeeded() async -> Result<Void, BluetoothError> {
        defer {
            self.runningDeviceConnectionTask = nil
        }
        
        guard self.runningDeviceConnectionTask == nil else {
            return await self.runningDeviceConnectionTask!.value
        }
        
        self.runningDeviceConnectionTask = Task(priority: .userInitiated) {
            if case let .failure(error) = await self.prepareCentralManager() {
                return .failure(error)
            }
            
            guard let volcano = self.volcano else {
                return .failure(.deviceNotFound)
            }
            
            guard volcano.state != .connected,
                  volcano.state != .connecting else {
                return .success(())
            }
            
            self.centralManager.connect(volcano, options: nil)
            let _ = await NotificationCenter.default
                                            .notifications(named: .deviceConnected).first(where: { _ in true })
            return .success(())
        }
        
        return await self.runningDeviceConnectionTask!.value
    }
    
    private func discoverVolcano() async -> Result<CBPeripheral, BluetoothError> {
        defer {
            self.runningDeviceSearchTask = nil
        }
        
        guard self.runningDeviceSearchTask == nil else {
            return await self.runningDeviceSearchTask!.value
        }
        
        self.runningDeviceSearchTask = Task(priority: .userInitiated) {
            if case let .failure(error) = await self.prepareCentralManager() {
                return .failure(error)
            }
            
            print("entering device search loop")
            guard self.volcano == nil else {
                print("looking for old fart")
                guard let newVolcano = self.centralManager.retrievePeripherals(withIdentifiers: [self.volcano!.identifier]).first else {
                    return .failure(.deviceNotFound)
                }
                self.volcano = newVolcano
                newVolcano.delegate = self.cBDelegate
                print("found an old fart")
                return .success(newVolcano)
            }
            
            let volcano: CBPeripheral? = await withTaskGroup(of: CBPeripheral?.self) { taskGroup in
                taskGroup.addTask {
                    await self.centralManager.scanForPeripherals(withServices: nil, options: nil)
                    let volcano = await NotificationCenter.default
                                                        .notifications(named: .deviceDiscovered)
                                                        .first(where: { _ in true })?
                                                        .userInfo?["device"] as? CBPeripheral
                    await self.centralManager.stopScan()
                    return volcano
                }
                taskGroup.addTask {
                    // timeout task
                    try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                    return nil
                }
                
                for await result in taskGroup {
                    // return the result of the first task to finish
                    taskGroup.cancelAll()
                    return result
                }
                return nil
            }
            
            guard let volcano = volcano else {
                return .failure(.deviceNotFound)
            }
            return .success(volcano)
        }
        
        return await self.runningDeviceSearchTask!.value
    }
    
    private func discoverRequiredServices() async -> [CBService] {
        defer {
            self.runningServiceSearchTask = nil
        }
        
        guard self.runningServiceSearchTask == nil else {
            return await self.runningServiceSearchTask!.value
        }
        
        self.runningServiceSearchTask = Task(priority: .userInitiated) {
            guard let volcano = self.volcano,
                  case .success = await self.prepareCentralManager(),
                  case .success = await self.connectIfNeeded() else {
                return []
            }
            
            volcano.discoverServices(nil)
            let discoveredServicesNotification = await NotificationCenter.default
                                                                        .notifications(named: .servicesDiscovered)
                                                                        .first(where: { _ in true })
            return discoveredServicesNotification?.userInfo?["services"] as? [CBService] ?? []
        }
        
        return await self.runningServiceSearchTask!.value
    }
    
    private func discoverRequiredCharacteristics() async -> [CBCharacteristic] {
        defer {
            self.runningCharacteristicSearchTask = nil
        }
        
        guard self.runningCharacteristicSearchTask == nil else {
            return await self.runningCharacteristicSearchTask!.value
        }
        
        self.runningCharacteristicSearchTask = Task(priority: .userInitiated) {
            guard let volcano = self.volcano,
                  let services = self.services,
                  case .success = await self.prepareCentralManager(),
                  case .success = await self.connectIfNeeded() else {
                return []
            }
            
            for (service, charUUIDS) in zip(services.allServices, 
                                            [BLECharacteristics.service1CharUUIDs, 
                                             BLECharacteristics.service2CharUUIDs]) {
                volcano.discoverCharacteristics(charUUIDS, for: service)
            }
            
            let characteristics = await NotificationCenter.default
                    .notifications(named: .charsDiscovered)
                    .filter { services.allServices.contains($0.userInfo?["service"] as! CBService) }
                    .prefix(2)
                    .compactMap({ $0.userInfo?["chars"] as? [CBCharacteristic] })
                    .reduce([CBCharacteristic](), { $0 + $1 })
            
            return characteristics
        }
        return await self.runningCharacteristicSearchTask!.value
    }
}

// MARK: - BluetoothServiceCBDelegate

fileprivate final class BluetoothServiceCBDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var currentManagerState = CBManagerState.unknown
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.currentManagerState = central.state
    }
    
    func centralManager(_ central: CBCentralManager, 
                        didDiscover peripheral: CBPeripheral, 
                        advertisementData: [String : Any], 
                        rssi RSSI: NSNumber) {
        guard peripheral.name?.contains("VOLCANO") == true else {
            return
        }
        NotificationCenter.default.post(.deviceDiscovered(peripheral))
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NotificationCenter.default.post(.deviceConnected())
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        NotificationCenter.default.post(.servicesDiscovered(services))
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        NotificationCenter.default.post(.charsDiscovered(characteristics, for: service))
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let newValue = characteristic.value else {
            return
        }
        NotificationCenter.default.post(.charRead(characteristic, data: newValue))
    }
}
