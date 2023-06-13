import SwiftUI

struct ScannerView: View {
    
    private let toggleInterval: TimeInterval = 3.0
    
    @Environment(\.backgroundColor) var backgroundColor: Color
    
    let animationLength: Double
    @Binding var isAnimating: Bool
    
    @State private var animationStartDate: Date = .distantPast
    
    var body: some View {
        ZStack {
            self.backgroundColor
            VStack(spacing: 24) {
                AnimatedVolcanoView(isAnimating: self.isAnimating)
                    .frame(height: 300)
                    .padding()
                if self.isAnimating == false {
                    Button(action: {
                        withAnimation(.easeInOut) {
                            self.animationStartDate = Date()
                            self.isAnimating = true
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue)
                            Text("Begin scan")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .font(.title2)
                        }
                        .frame(width: 200, height: 48)
                        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 8))
                        .contentShape(.interaction, RoundedRectangle(cornerRadius: 8))
                    }
                    .hoverEffect()
                } else {
                    TimelineView(.animation(paused: !self.isAnimating)) { context in
                        VStack(spacing: 24) {
                            ProgressView(value: self.progress(for: context.date))
                                .padding(.horizontal, 16)
                                .frame(maxWidth: 600)
                            Text(self.scanningText(for: context.date))
                                .frame(alignment: .leading)
                                .font(.title2)
                                .scaleEffect(self.textScaleFactor(for: context.date))
                        }
                    }
                    .padding()
                }
            }
            .offset(x: 0, y: self.isAnimating ? -100 : 0)
            .transition(.scale(scale: 1.5).combined(with: .move(edge: .top)))
        }
    }
    
    private func textScaleFactor(for date: Date) -> Double {
        let growthInterval = 0.15
        guard date != .distantPast else {
            // start with small text initially
            return 1
        }
        let timeSinceStart = date.timeIntervalSince(self.animationStartDate)
        let isGrowing = Int(timeSinceStart / self.toggleInterval) % 2 == 0
        let percentToNextTransition = timeSinceStart
                        .truncatingRemainder(dividingBy: self.toggleInterval)
                        / self.toggleInterval
        let growthFactor = isGrowing 
                            ? percentToNextTransition 
                            : 1 - percentToNextTransition 
        return 1 + (growthInterval * growthFactor)
    }

    private func scanningText(for date: Date) -> String {
        let toggleInterval = self.toggleInterval / 4
        let diff = Int(date.timeIntervalSince(self.animationStartDate) / toggleInterval)
        switch diff % 4 {
        case 0: return "Scanning"
        case 1: return "Scanning."
        case 2: return "Scanning.."
        case 3: return "Scanning..."
        default: return "Broken!"
        }
    }
    
    private func progress(for date: Date) -> Double {
        let difference = date.timeIntervalSince(self.animationStartDate) / self.animationLength
        return difference
    }
}

struct ScannerView_Previews: PreviewProvider {
    static var previews: some View {
        ScannerView(animationLength: ProductionBluetoothService.scanLength,
                    isAnimating: .constant(false))
    }
}
