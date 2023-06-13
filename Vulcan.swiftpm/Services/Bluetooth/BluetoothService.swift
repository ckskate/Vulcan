//
//  CCBCentralManager.swift
//  CCBCentralManager
//
//  Created by Connor Killion on 9/12/21.
//

import Foundation
import CoreBluetooth

enum BluetoothError: LocalizedError, Identifiable {
    case deviceNotFound, disconnected, unsupported, permissionDenied
    
    var id: Self { return self }
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
    
    static var scanLength: TimeInterval { get }
}

extension BluetoothService {
    static var scanLength: TimeInterval { return 10.0 }
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
    
    public var isConnectedAndReady: Bool {
        guard self.chars != nil,
              self.services != nil,
              let connectionState = self.volcano?.state else {
            return false
        }
        return connectionState == .connected
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
            return .failure(.deviceNotFound)
        }
        volcano.delegate = self.cBDelegate
        self.volcano = volcano
        // connect
        if case let .failure(error) = await self.connectIfNeeded() {
            return .failure(error)
        }
        // discover and store required services and characteristics
        self.services = BLEServices(await self.discoverRequiredServices())
        self.chars = BLECharacteristics(await self.discoverRequiredCharacteristics())
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
    
    // MARK: getting/setting state
    
    public func getCurrTemp() async -> Result<Temperature, BluetoothError> {
        guard let chars = self.chars else {
            return .failure(.disconnected)
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
        return .success(Temperature(data: devCurrTemp))
    }
    
    public func getTargTemp() async -> Result<Temperature, BluetoothError> {
        guard let chars = self.chars else {
            return .failure(.disconnected)
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
        return .success(Temperature(data: devTargTemp))
    }
    
    public func set(temp: Temperature) async {
        guard let chars = self.chars else {
            fatalError("Need the characteristics")
        }
        await self.writeValue(temp.asData, for: chars.targTempChar)
    }
    
    public func getHeatAirState() async -> Result<HeatAirState, BluetoothError> {
        guard let chars = self.chars else {
            return .failure(.disconnected)
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
        
        return .success(HeatAirState(data: devHeatAirState))
    }
    
    public func set(heatAirState: HeatAirState) async {
        guard let chars = self.chars else {
            return
        }
        
        await withTaskGroup(of: Void.self) { taskGroup in
            let charsToWrite: (air: CBCharacteristic, heat: CBCharacteristic)
            switch heatAirState {
            case .allOff: charsToWrite = (air: chars.stopAirChar, heat: chars.stopHeatChar)
            case .heatOn: charsToWrite = (air: chars.stopAirChar, heat: chars.startHeatChar)
            case .heatAndAirOn: charsToWrite = (air: chars.startAirChar, heat: chars.startHeatChar)
            }
            taskGroup.addTask {
                await self.writeValue(Data(repeating: 1, count: 1), for: charsToWrite.air)
            }
            taskGroup.addTask {
                await self.writeValue(Data(repeating: 1, count: 1), for: charsToWrite.heat)
            }
            await taskGroup.waitForAll()
        }
    }
    
    // MARK: Data transfer helpers
    
    private func readValue(for characteristic: CBCharacteristic) async -> Data? {
        guard self.runningCharacteristicReadTasks[characteristic] == nil else {
            return await self.runningCharacteristicReadTasks[characteristic]!.value
        }
        
        defer {
            self.runningCharacteristicReadTasks.removeValue(forKey: characteristic)
        }
        
        let readTask = Task(priority: .userInitiated) { () -> Data? in
            guard let volcano = self.volcano,
                  case .success = await self.prepareCentralManager(),
                  case .success = await self.connectIfNeeded() else {
                return nil
            }
            volcano.readValue(for: characteristic)
            let newValue = await NotificationCenter
                                    .default
                                    .notifications(named: .charRead)
                                    .map { (char: $0.userInfo?["char"] as? CBCharacteristic,
                                            data: $0.userInfo?["data"] as? Data) }
                                    .first(where: { $0.char == characteristic })?
                                    .data
            return newValue
        }
        self.runningCharacteristicReadTasks[characteristic] = readTask
        return await readTask.value
    }
    
    private func writeValue(_ data: Data, for characteristic: CBCharacteristic) async {
        guard let volcano = self.volcano,
              case .success = await self.prepareCentralManager(),
              case .success = await self.connectIfNeeded() else {
            return
        }
        volcano.writeValue(data,
                           for: characteristic,
                           type: .withResponse)
    }
    
    // MARK: Discovery helpers
    
    private func prepareCentralManager() async -> Result<(), BluetoothError> {
        guard self.centralManager.state != .unsupported else {
            return .failure(.unsupported)
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
        guard self.runningDeviceConnectionTask == nil else {
            return await self.runningDeviceConnectionTask!.value
        }
        
        defer {
            self.runningDeviceConnectionTask = nil
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
            let connectionResult = await withTaskGroup(of: Bool.self) { taskGroup in
                taskGroup.addTask {
                    return await NotificationCenter.default
                        .notifications(named: .deviceConnected)
                        .map { $0.name }
                        .contains(where: { $0 == .deviceConnected }) // nop
                }
                taskGroup.addTask {
                    try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                    return false
                }
                for await result in taskGroup {
                    taskGroup.cancelAll()
                    return result
                }
                return false
            }
                                            
            return connectionResult
                    ? .success(())
                    : .failure(.deviceNotFound)
        }
        
        return await self.runningDeviceConnectionTask!.value
    }
    
    private func discoverVolcano() async -> Result<CBPeripheral, BluetoothError> {
        guard self.runningDeviceSearchTask == nil else {
            return await self.runningDeviceSearchTask!.value
        }
        
        defer {
            self.runningDeviceSearchTask = nil
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
                    self.centralManager.scanForPeripherals(withServices: nil, options: nil)
                    let volcano = await NotificationCenter.default
                                                        .notifications(named: .deviceDiscovered)
                                                        .first(where: { _ in true })?
                                                        .userInfo?["device"] as? CBPeripheral
                    self.centralManager.stopScan()
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
        guard self.runningServiceSearchTask == nil else {
            return await self.runningServiceSearchTask!.value
        }
        
        defer {
            self.runningServiceSearchTask = nil
        }
        
        self.runningServiceSearchTask = Task(priority: .userInitiated) {
            guard let volcano = self.volcano,
                  case .success = await self.prepareCentralManager(),
                  case .success = await self.connectIfNeeded() else {
                return []
            }
            
            volcano.discoverServices(nil)
            let discoveredServices = await NotificationCenter.default
                                                             .notifications(named: .servicesDiscovered)
                                                             .compactMap { $0.userInfo?["services"] as? [CBService] }
                                                             .first(where: { _ in true })
            return discoveredServices ?? []
        }
        
        return await self.runningServiceSearchTask!.value
    }
    
    private func discoverRequiredCharacteristics() async -> [CBCharacteristic] {
        guard self.runningCharacteristicSearchTask == nil else {
            return await self.runningCharacteristicSearchTask!.value
        }
        
        defer {
            self.runningCharacteristicSearchTask = nil
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
    
    @MainActor
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
//        MainActor.run {
//            Services.shared.volcanoManager.set(state: )
//        }
    }
    
    @MainActor
    func centralManager(_ central: CBCentralManager, 
                        didDiscover peripheral: CBPeripheral, 
                        advertisementData: [String : Any], 
                        rssi RSSI: NSNumber) {
        guard let volcano = peripheral.asVolcano else {
            return
        }
        NotificationCenter.default.post(.deviceDiscovered(volcano))
    }
    
    @MainActor
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        NotificationCenter.default.post(.deviceConnected())
        Services.shared.volcanoManager.set(state: .connected)
    }
    
    @MainActor
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        Services.shared.volcanoManager.set(state: .disconnected)
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        NotificationCenter.default.post(.servicesDiscovered(services))
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        NotificationCenter.default.post(.charsDiscovered(characteristics, for: service))
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let newValue = characteristic.value else {
            return
        }
        NotificationCenter.default.post(.charRead(characteristic, data: newValue))
    }
}
