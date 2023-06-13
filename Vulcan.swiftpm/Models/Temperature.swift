import SwiftUI

struct Temperature: Equatable {
    static let zero: Temperature = .farenheit(0)
    
    enum Unit {
        case celsius, farenheit
    }
    
    private var celsiusVal: Int
    
    static func farenheit(_ degrees: Int) -> Self {
        let celsiusVal = (Double(degrees) - 32.0) * (5/9)
        return Temperature(celsiusVal: Int(celsiusVal))
    }
    
    static func celcius(_ degrees: Int) -> Self {
        return Temperature(celsiusVal: degrees)
    }
    
    init(data: Data) {
        let scaledUpTemp = data.withUnsafeBytes {
            $0.load(as: Int32.self).littleEndian
        }
        self.celsiusVal = Int(Double(scaledUpTemp) / 10.0)
    }
    
    // no public initializer
    private init(celsiusVal: Int) {
        self.celsiusVal = celsiusVal
    }
   
    // MARK: - reading values
    
    func value(unit: Unit = .farenheit) -> Int {
        switch unit {
        case .celsius: return self.celsiusVal
        case .farenheit: return Int(round(((9/5) * Double(self.celsiusVal)) + 32.0))
        }
    }
    
    var asData: Data {
        let scaledIntTemp = Int32(self.celsiusVal * 10)
        return withUnsafeBytes(of: scaledIntTemp.littleEndian) { Data($0) }
    }
    
    // MARK: - operators 
    
    static func +=(lhs: inout Temperature, rhs: Temperature) {
        lhs.celsiusVal += rhs.celsiusVal
    }
    
    static func -=(lhs: inout Temperature, rhs: Temperature) {
        lhs.celsiusVal -= rhs.celsiusVal
    }
}
