import SwiftUI

enum HeatAirState {
    case heatOn, heatAndAirOn, allOff
    
    var isHeatOn: Bool {
        switch self {
        case .allOff: return false
        case .heatOn, .heatAndAirOn: return true
        }
    }
    
    var isAirOn: Bool {
        switch self {
        case .heatAndAirOn: return true
        case .heatOn, .allOff: return false
        }
    }
    
    init(isHeatOn: Bool, isAirOn: Bool) {
        switch (isHeatOn, isAirOn) {
        case (true, true): self = .heatAndAirOn
        case (true, false): self = .heatOn
        case (false, _): self = .allOff
        }
    }
    
    init(data: Data) {
        self = .allOff
        
        guard data.count >= 2 else {
            return
        }
        
        let isHeatEnabled = data[0] == 0x23
        let isAirEnabled = data[1] >> 4 == 0x03
        
        if isHeatEnabled && isAirEnabled {
            self = .heatAndAirOn;
        } else if isHeatEnabled {
            self = .heatOn;
        }
    }
}
