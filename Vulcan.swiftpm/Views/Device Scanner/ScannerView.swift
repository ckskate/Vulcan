import SwiftUI

struct ScannerView: View {
    
    @Binding var isAnimating: Bool
    @State private var hasBigScanningText = false
    @State private var scanningTextDotsCount: DeviceScanningView.ScanningDotsCount = .zero
    @State private var progress = 0.0
    @State private var counter = 0
    
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black
            DeviceScanningView(isAnimating: self.$isAnimating,
                               progress: self.$progress,
                               hasBigScanningText: self.$hasBigScanningText,
                               scanningTextDotsCount: self.$scanningTextDotsCount)
        }
        .onReceive(self.timer) { _ in
            guard self.isAnimating else {
                return
            }
            
            if self.progress < 1 {
                self.progress += 1 / 333
                self.progress = min(self.progress, 1)
            }
            
            self.counter += 1
            
            switch self.counter {
            case 0..<25:
                self.scanningTextDotsCount = .zero
            case 25..<50:
                self.scanningTextDotsCount = .one
            case 50..<75:
                self.scanningTextDotsCount = .two
            case 75..<100:
                self.scanningTextDotsCount = .three
            default:
                self.counter = 0
                self.hasBigScanningText.toggle()
            }
        }
    }
}

struct DeviceScanningView: View {
    
    enum ScanningDotsCount: String {
        case zero = "Scanning"
        case one = "Scanning."
        case two = "Scanning.."
        case three = "Scanning..."
    }
    
    @Binding var isAnimating: Bool
    @Binding var progress: Double
    
    @Binding var hasBigScanningText: Bool
    @Binding var scanningTextDotsCount: ScanningDotsCount
    
    var body: some View {
        VStack {
            AnimatedVolcanoView(isAnimating: self.isAnimating)
                .frame(height: 300)
                .padding()
            if self.isAnimating == false {
                Button(action: {
                    withAnimation(.easeInOut) {
                        self.isAnimating = true
                    }
                }) {
                    Text("Begin scan")
                        .fontWeight(.medium)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue)
                                .frame(minWidth: 200, minHeight: 48)
                        }
                        .foregroundColor(.primary)
                        .font(.title2)
                        .padding()
                }
                .padding()
            } else {
                ProgressView(value: self.progress)
                    .padding()
                    .frame(maxWidth: 600)
                Text(self.scanningTextDotsCount.rawValue)
                    .frame(alignment: .leading)
                    .font(.title2)
                    .scaleEffect(self.hasBigScanningText ? 1.15 : 1)
                    .animation(.linear(duration: 3), value: self.hasBigScanningText)
            }
        }
        .offset(x: 0, y: self.isAnimating ? -100 : 0)
        .transition(.scale(scale: 1.5).combined(with: .move(edge: .top)))
    }
}

struct ScannerView_Previews: PreviewProvider {
    static let services = Services(isDebugMode: true)
    
    static var previews: some View {
        ScannerView(isAnimating: .constant(false))
    }
}
