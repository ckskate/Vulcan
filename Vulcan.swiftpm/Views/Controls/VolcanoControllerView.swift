//
//  VolcanoControllerView.swift
//  VolcanoControllerView
//
//  Created by Connor Killion on 9/20/21.
//

import SwiftUI

struct VolcanoControllerView: View {
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    @StateObject var viewModel: VolcanoControllerViewModel
    
    @State var currTemp: Int = 360
    @State var targTemp: Int = 400
    @State var isHeating: Bool = false
    @State var isAirOn: Bool = false
    
    private var backgroundColor: Color {
        return (self.colorScheme == .dark) 
                    ? .black 
                    : .white
    }
    
    var body: some View {
        ZStack {
            LinearGradient(stops: [.init(color: .accentColor, location: 0),
                                    .init(color: self.backgroundColor, location: 0.65)],
                           startPoint: .top,
                           endPoint: .bottom)
                        .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Temperature")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Text("\(self.currTemp)º F")
                            .font(.system(size: 64))
                            .fontWeight(.heavy)
                            .frame(minWidth: 200, idealWidth: 300, alignment: .leading)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 24,
                                     style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Set Temperature")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            
                        HStack() {
                            Spacer()
                            TemperatureButton(type: .minus, value: self.$targTemp)
                            TemperatureLabel(value: self.$targTemp, smoothValue: Double(self.targTemp))
                            TemperatureButton(type: .plus, value: self.$targTemp)
                            Spacer()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Device Control")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            ControlButton(type: .power, toggled: self.$isHeating)
                            ControlButton(type: .wind, toggled: self.$isAirOn)
                        }
                    }
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 24,
                                     style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .padding()
            .frame(maxWidth: 640)
        }
        .onChange(of: self.targTemp) { _ in
            self.viewModel.setTargTemp(to: self.targTemp)
        }
        .onChange(of: self.isAirOn) { _ in
            self.viewModel.setHeatAirState(isHeatOn: self.isHeating, isAirOn: self.isAirOn)
        }
        .onChange(of: self.isHeating) { _ in
            self.viewModel.setHeatAirState(isHeatOn: self.isHeating, isAirOn: self.isAirOn)
        }
        .task {
            while true {
                for await newState in self.viewModel.backgroundUpdateStream {
                    self.targTemp = newState.targTemp.asFahrInt
                    self.currTemp = newState.currTemp.asFahrInt
                    switch newState.heatAirState {
                    case .allOff:
                        self.isAirOn = false
                        self.isHeating = false
                    case .heatAndAirOn:
                        self.isAirOn = true
                        self.isHeating = true
                    case .heatOn:
                        self.isAirOn = false
                        self.isHeating = true
                    }
                }
            }
        }
    }
}


struct TemperatureButton: View {
    enum buttonType: String {
        case plus, minus
    }
    
    @State var type: buttonType = .plus
    @Binding var value: Int
    
    @GestureState var isTapping: Bool = false
    @GestureState var isDetectingLongPress = false
    @State var isDetectingVeryLongPress = false
    
    @State var timer: Timer?
    @State var feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    var longPress: some Gesture {
        return LongPressGesture()
            .sequenced(before: LongPressGesture(minimumDuration: .infinity))
            .updating(self.$isTapping) { value, state, transaction in
                switch value {
                case .first(true):
                    state = true
                    self.feedbackGenerator.impactOccurred(intensity: 0.6)
                default:
                    break
                }
            }
            .updating(self.$isDetectingLongPress) { value, state, transaction in
                switch value {
                case .second(true, nil):
                    state = true
                default:
                    break
                }
            }
    }
    
    func updateValue() {
        switch self.type {
        case .plus:
            self.value += 1
        case .minus:
            self.value -= 1
        }
    }
    
    var body: some View {
        Button(action: {
            self.updateValue()
            self.feedbackGenerator.impactOccurred(intensity: 0.6)
        }) {
            ZStack {
                Circle()
                    .fill(self.isTapping
                          ? Color.primary
                          : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(lineWidth: 3)
                            .fill(Color.primary)
                    )
                    .frame(width: 64, height: 64)
                    .shadow(radius: 8)
                    .animation(.easeInOut(duration: 0.22), value: self.isDetectingLongPress)
                Image(systemName: self.type.rawValue)
                    .font(.system(size: 32))
                    .foregroundColor(self.isTapping
                                     ? Color.white
                                     : Color.primary)
            }
        }
        .scaleEffect(self.isDetectingVeryLongPress
                     ? 1.3
                     : self.isDetectingLongPress
                       ? 1.2
                       : self.isTapping
                         ? 1.1
                         : 1)
        .simultaneousGesture(self.longPress)
        .onChange(of: self.isDetectingLongPress) { _ in
            guard self.isDetectingLongPress else {
                self.timer?.invalidate()
                self.timer = nil
                self.isDetectingVeryLongPress = false
                self.feedbackGenerator.impactOccurred(intensity: 0.6)
                return
            }
            
            self.feedbackGenerator.impactOccurred(intensity: 0.8)
            self.feedbackGenerator.prepare()
            guard self.timer == nil else {
                return
            }
            
            var repeatCount = 0
            
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { state in
                
                self.isDetectingVeryLongPress = (repeatCount >= 20)
                
                switch self.type {
                case .plus:
                    self.value += (self.isDetectingVeryLongPress) ? 2 : 1
                case .minus:
                    self.value -= (self.isDetectingVeryLongPress) ? 2 : 1
                }
                
                if repeatCount == 20 {
                    self.feedbackGenerator.impactOccurred(intensity: 1)
                    self.feedbackGenerator.prepare()
                }
                
                repeatCount += 1
            }
            
        }
    }
}


struct ControlButton: View {
    
    enum ButtonType: String {
        case power, wind
    }
    
    @State var type: ButtonType = .power
    @Binding var toggled: Bool
    @State var pressed: Bool = false
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    private var secondaryColor: Color {
        return (self.colorScheme == .dark) 
            ? .black 
            : .white
    }
    
    var body: some View {
        Button(action: {}) {
            ZStack {
                Rectangle()
                    .fill(self.toggled ? Color.primary : Color.clear)
                    .border(Color.primary, width: 3)
                    .cornerRadius(6)
                .frame(height: 64)
                Image(systemName: self.type.rawValue)
                    .font(.largeTitle)
                    .foregroundColor(self.toggled ? self.secondaryColor : Color.primary)
                    
            }
        }
        .scaleEffect(self.pressed ? 1 : 0.9)
        .animation(.easeInOut(duration: 0.22), value: self.pressed)
        .onLongPressGesture(minimumDuration: .infinity,
                            perform: {},
                            onPressingChanged: { isPressed in
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
            feedbackGenerator.impactOccurred()
            
            self.pressed = isPressed
            if isPressed == false {
                self.toggled = !self.toggled
            }
        })
    }
}


struct TemperatureLabel: View {
    
    @Binding var value: Int
    @State var smoothValue: Double
    @State var selectionFeedbackGenerator: UISelectionFeedbackGenerator?
    
    @GestureState var dragging = false
    
    var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating(self.$dragging) { value, state, transaction in
                state = true
                self.selectionFeedbackGenerator?.prepare()
            }
            .onChanged { dragValue in
                
                if self.selectionFeedbackGenerator == nil {
                    self.selectionFeedbackGenerator = UISelectionFeedbackGenerator()
                    self.selectionFeedbackGenerator?.prepare()
                }
                
                let isDragUp = (dragValue.predictedEndLocation.y < dragValue.location.y)
                let dragOffset = abs(dragValue.predictedEndLocation.y - dragValue.location.y)
                let scaledOffset = dragOffset / 50
                
                if abs(self.smoothValue - Double(self.value)) > 1 {
                    self.smoothValue = Double(self.value)
                }
            
                if isDragUp {
                    self.smoothValue += scaledOffset
                } else {
                    self.smoothValue -= scaledOffset
                }
                
                let clampedValue = Int(smoothValue)
                
                if clampedValue != self.value {
                    self.selectionFeedbackGenerator?.selectionChanged()
                    self.selectionFeedbackGenerator?.prepare()
                }
                
                self.value = clampedValue
            }
    }
    
    var body: some View {
        Text("\(self.value)º F")
            .font(.title)
            .fontWeight(.medium)
            .frame(width: 110,
                   height: nil,
                   alignment: .center)
            .scaleEffect(self.dragging ? 1.2 : 1)
            .animation(.easeInOut(duration: 0.1), value: self.dragging)
            .gesture(self.drag)
    }
}

struct VolcanoControllerView_Previews: PreviewProvider {
    static var previews: some View {
        VolcanoControllerView(viewModel: VolcanoControllerViewModel(bluetoothService: Services(isDebugMode: true).bluetoothService))
    }
}
