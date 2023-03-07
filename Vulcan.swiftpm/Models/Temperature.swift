import SwiftUI

struct Temperature {
    private let actualCelciusVal: Double
    
    static let zero: Temperature = Temperature(actualCelciusVal: 0.0)
    
    static func from(data: Data) -> Temperature {
        let scaledUpTemp = data.withUnsafeBytes {
            $0.load(as: Int32.self).littleEndian
        }
        return Temperature(actualCelciusVal: Double(scaledUpTemp) / 10.0)
    }
    
    static func from(fahrInt: Int) -> Temperature {
        let celciusVal = (Double(fahrInt) - 32.0) * (5/9)
        return Temperature(actualCelciusVal: celciusVal)
    }
    
    var asFahrInt: Int {
        Int(round(((9/5) * self.actualCelciusVal) + 32.0))
    }
    
    var asData: Data {
        let scaledIntTemp = Int32(self.actualCelciusVal * 10.0)
        return withUnsafeBytes(of: scaledIntTemp.littleEndian) { Data($0) }
    }
}
