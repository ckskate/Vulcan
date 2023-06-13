import SwiftUI

enum VolcanoState: Equatable {
    case error(BluetoothError)
    case disconnected
    case connected
    
    var error: BluetoothError? {
        switch self {
        case let .error(error): return error
        default: return nil
        }
    }
    
    init(_ bluetoothError: BluetoothError) {
        self = .error(bluetoothError)
    }
}

@MainActor
final class VolcanoManager: ObservableObject {
    
    let scanDuration: TimeInterval = 10.0
    
    private var writeTempTask: Task<Void, Never>?
    private var writeHeatAirStateTask: Task<Void, Never>?
    private var discoveryScanTask: Task<Void, Never>?
    private var isTargTempFreshlyWritten = false
    private var isHeatAirFreshlyWritten = false
    
    @Published private(set) var state: VolcanoState = .disconnected
    @Published private(set) var currTemp: Temperature = .zero
    @Published private(set) var discoveredDevices: [Volcano] = []
    
    private var _targTemp: Temperature = .zero
    var targTemp: Binding<Temperature> {
        Binding {
            return self._targTemp
        } set: { value in
            print(value)
        }
    }
    
    private var _heatAirState: HeatAirState = .allOff
    var isHeatOn: Binding<Bool> {
        Binding {
            return self._heatAirState.isHeatOn
        } set: { value in
            self.set(isHeatOn: value)
        }
    }
    var isAirOn: Binding<Bool> {
        Binding {
            return self._heatAirState.isAirOn
        } set: { value in
            self.set(isAirOn: value)
        }
    }
    
    func runDiscoveryScan() {
        guard self.state == .disconnected else {
            fatalError("running discovery scan when not in right state")
            return
        }
    }
    
    func readDeviceUpdates() async {
        let bluetoothService = Services.shared.bluetoothService
//            print("VolcanoControlViewModel starting background read stream")
        while true {
            guard self.state == .connected else {
                return
            }
            
            do {
                // start reading updates
                async let currTemp = bluetoothService.getCurrTemp()
                async let targTemp = bluetoothService.getTargTemp()
                async let heatAirState = bluetoothService.getHeatAirState()
                
                // wait for the reads to finish
                guard case let .success(currTemp) = await currTemp,
                      case let .success(targTemp) = await targTemp,
                      case let .success(heatAirState) = await heatAirState else {
                    break
                }
                
                // apply the updates
                self.objectWillChange.send()
                self.currTemp = currTemp
                if self.writeTempTask == nil {
                    self._targTemp = targTemp
                    self.isTargTempFreshlyWritten = false
                }
                if self.writeHeatAirStateTask == nil {
                    self._heatAirState = heatAirState
                    self.isHeatAirFreshlyWritten = false
                }
                
                // wait 4 seconds before next read
                try await Task.sleep(nanoseconds: 4 * 1_000_000_000)
            } catch {
                break
            }
        }
    }
    
    func set(state: VolcanoState) {
        guard state != self.state else {
            return
        }
        self.objectWillChange.send()
        self.state = state
    }
    
    private func set(targetTemp: Temperature) {
        self.writeTempTask?.cancel()
        self.isTargTempFreshlyWritten = true
        self._targTemp = targetTemp
        self.writeTempTask = Task.detached {
            do {
                // delay to prevent spamming requests
                try await Task.sleep(nanoseconds: 300 * 1000) // 300 ms
            } catch {
                return
            }
            await Services.shared.bluetoothService.set(temp: targetTemp)
        }
    }
    
    private func set(isHeatOn: Bool? = nil,
                     isAirOn: Bool? = nil) {
        let newState = HeatAirState(isHeatOn: isHeatOn ?? self._heatAirState.isHeatOn,
                                    isAirOn: isAirOn ?? self._heatAirState.isAirOn)
        guard self._heatAirState != newState else {
            return
        }
        self.writeTempTask?.cancel()
        self.isHeatAirFreshlyWritten = true
        self._heatAirState = newState
        self.writeHeatAirStateTask = Task.detached {
            do {
                try await Task.sleep(nanoseconds: 300 * 1000) // 300 ms
            } catch {
                return
            }
            await Services.shared.bluetoothService.set(heatAirState: newState)
        }
    }
}
