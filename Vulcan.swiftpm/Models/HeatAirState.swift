import SwiftUI

enum HeatAirState {
    case heatOn, heatAndAirOn, allOff
    
    static func from(data: Data) -> HeatAirState {
        guard data.count >= 2 else {
            return .allOff
        }
        
        let isHeatEnabled = data[0] == 0x23
        let isAirEnabled = data[1] >> 4 == 0x03
        
        if isHeatEnabled && isAirEnabled {
            return .heatAndAirOn;
        } else if isHeatEnabled {
            return .heatOn;
        }
        return .allOff
    }
}
