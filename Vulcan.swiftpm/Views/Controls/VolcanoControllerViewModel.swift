import SwiftUI

struct VolcanoState {
    let currTemp: Temperature
    let targTemp: Temperature
    let heatAirState: HeatAirState
}

@MainActor
class VolcanoControllerViewModel: ObservableObject {
    
    private let bluetoothService: BluetoothService
    
    private var writeTempTask: Task<Void, Never>?
    private var writeHeatAirStateTask: Task<Void, Never>?
    
    init(bluetoothService: BluetoothService) {
        self.bluetoothService = bluetoothService
    }

    var backgroundUpdateStream: AsyncStream<VolcanoState> {
        return AsyncStream { continuation in
            let updateTask = Task.detached {
                do {
                    while true {
                        if await self.bluetoothService.isConnectedAndReady == false {
                            try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                            continue
                        }
                        
                        guard case let .success(currTemp) = await self.bluetoothService.getCurrTemp(),
                              case let .success(targTemp) = await self.bluetoothService.getTargTemp(),
                              case let .success(heatAirState) = await self.bluetoothService.getHeatAirState() else {
                            continue
                        }
                        
                        let state = VolcanoState(currTemp: currTemp, 
                                                 targTemp: targTemp, 
                                                 heatAirState: heatAirState)
                        if await self.writeTempTask == nil,
                           await self.writeHeatAirStateTask == nil {
                            continuation.yield(state)
                        }
                        try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                    }
                } catch {
                    continuation.finish()
                    return
                }
            }
            continuation.onTermination = { @Sendable _ in
                updateTask.cancel()
            }
        }
    }
    
    func setTargTemp(to newTemp: Int) {
        self.writeTempTask?.cancel()
        self.writeTempTask = Task.detached {
            do {
                try await Task.sleep(nanoseconds: 200 * 1_000_000) // .2 seconds
            } catch {
                return
            }
            await self.bluetoothService.set(temp: Temperature.from(fahrInt: newTemp))
            await MainActor.run {
                self.writeTempTask = nil
            }
        }
    }
    
    func setHeatAirState(isHeatOn: Bool, isAirOn: Bool) {
        self.writeHeatAirStateTask?.cancel()
        self.writeHeatAirStateTask = Task.detached {
            do {
                try await Task.sleep(nanoseconds: 200 * 1_000_000) // .2 seconds
            } catch {
                return
            }
            
            switch (isAirOn, isHeatOn) {
            case (true, true):
                await self.bluetoothService.set(heatAirState: .heatAndAirOn)
            case (false, false),
                (true, false):
                await self.bluetoothService.set(heatAirState: .allOff)
            case (false, true):
                await self.bluetoothService.set(heatAirState: .heatOn)
            }
            
            await MainActor.run {
                self.writeHeatAirStateTask = nil
            }
        }
    }
}
