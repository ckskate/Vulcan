//
//  VolcanoControllerView.swift
//  VolcanoControllerView
//
//  Created by Connor Killion on 9/20/21.
//

import SwiftUI

struct VolcanoControllerView: View {
    
    @Environment(\.backgroundColor) var backgroundColor: Color
    @Service(\.volcanoManager) var volcanoManager: VolcanoManager
    
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
                        Text("\(self.volcanoManager.currTemp.value())º F")
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
                            TemperatureButton(type: .minus, value: self.volcanoManager.targTemp)
                            TemperatureLabel(value: self.volcanoManager.targTemp,
                                             smoothValue: Double(self.volcanoManager
                                                                     .targTemp
                                                                     .wrappedValue
                                                                     .value()))
                            TemperatureButton(type: .plus, value: self.volcanoManager.targTemp)
                            Spacer()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Device Control")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            ControlButton(type: .power, toggled: self.volcanoManager.isHeatOn)
                            ControlButton(type: .wind, toggled: self.volcanoManager.isAirOn)
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
//        .onChange(of: self.targTemp) { _ in
//            self.viewModel.setTargTemp(to: self.targTemp)
//        }
//        .onChange(of: self.isAirOn) { _ in
//            self.viewModel.setHeatAirState(isHeatOn: self.isHeating, isAirOn: self.isAirOn)
//        }
//        .onChange(of: self.isHeating) { _ in
//            print("heat button pressed")
//            self.viewModel.setHeatAirState(isHeatOn: self.isHeating, isAirOn: self.isAirOn)
//        }
        .task(id: self.volcanoManager.state) {
            await self.volcanoManager.readDeviceUpdates()
//            while true {
//                for await newState in self.viewModel.backgroundUpdateStream {
//                    self.targTemp = newState.targTemp.value()
//                    self.currTemp = newState.currTemp.value()
//                    switch newState.heatAirState {
//                    case .allOff:
//                        self.isAirOn = false
//                        self.isHeating = false
//                    case .heatAndAirOn:
//                        self.isAirOn = true
//                        self.isHeating = true
//                    case .heatOn:
//                        self.isAirOn = false
//                        self.isHeating = true
//                    }
//                }
//            }
        }
    }
}

struct TemperatureButton: View {
    @Environment(\.backgroundColor) var backgroundColor: Color
    
    enum buttonType: String {
        case plus, minus
    }
    
    let type: buttonType
    @Binding var value: Temperature
    
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
            self.value += .farenheit(1)
        case .minus:
            self.value -= .farenheit(1)
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.primary, lineWidth: 3)
                .background {
                    Circle()
                        .fill(self.isTapping
                              ? Color.primary
                              : Color.clear)
                }
            Image(systemName: self.type.rawValue)
                .font(.system(size: 32))
                .foregroundColor(self.isTapping
                                 ? self.backgroundColor
                                 : Color.primary)
        }
        .frame(width: 64, height: 64)
        .shadow(radius: 8)
        .animation(.easeInOut(duration: 0.22), value: self.isDetectingLongPress)
        .scaleEffect(self.isDetectingVeryLongPress
                     ? 1.3
                     : self.isDetectingLongPress
                       ? 1.2
                       : self.isTapping
                         ? 1.1
                         : 1)
        .contentShape(.hoverEffect, Circle())
        .contentShape(.interaction, Circle())
        .hoverEffect()
        .onTapGesture {
            self.updateValue()
            self.feedbackGenerator.impactOccurred(intensity: 0.6)
        }
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
                
                let change: Temperature = self.isDetectingVeryLongPress
                                    ? .farenheit(2)
                                    : .farenheit(1)
                switch self.type {
                case .plus: self.value += change
                case .minus: self.value -= change
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
    @Environment(\.backgroundColor) var backgroundColor: Color
    
    enum ButtonType: String {
        case power, wind
    }
    
    let type: ButtonType
    @Binding var toggled: Bool

    @State var pressed: Bool = false
    
    var body: some View {
        Toggle(isOn: self.$toggled) {
            ZStack {
                RoundedRectangle(cornerRadius: 6.0)
                    .fill()
                    .foregroundColor(self.toggled ? Color.primary : .clear)
                RoundedRectangle(cornerRadius: 6.0)
                    .strokeBorder(.primary, lineWidth: 3.0)
                Image(systemName: self.type.rawValue)
                    .font(.largeTitle)
                    .foregroundColor(self.toggled
                                     ? self.backgroundColor
                                     : .primary)
                
            }
            .frame(height: 64)
        }
        .toggleStyle(.button)
        .tint(.primary)
        .scaleEffect(self.pressed ? 1.03 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 6.0))
        .hoverEffect()
//        .onHover { hovering in
//            withAnimation {
//                self.pressed = hovering
//            }
//        }
        .animation(.easeInOut(duration: 0.22), value: self.pressed)
//        .onLongPressGesture(minimumDuration: .infinity,
//                            perform: {},
//                            onPressingChanged: { isPressed in
//            let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
//            feedbackGenerator.impactOccurred()
//            
//            self.pressed = isPressed
//            if isPressed == false {
//                self.toggled = !self.toggled
//            }
//        })
    }
}

struct TemperatureLabel: View {
    
    @Binding var value: Temperature
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
                
                if abs(self.smoothValue - Double(self.value.value())) > 1 {
                    self.smoothValue = Double(self.value.value())
                }
            
                if isDragUp {
                    self.smoothValue += scaledOffset
                } else {
                    self.smoothValue -= scaledOffset
                }
                
                let clampedValue = Int(smoothValue)
                
                if clampedValue != self.value.value() {
                    self.selectionFeedbackGenerator?.selectionChanged()
                    self.selectionFeedbackGenerator?.prepare()
                }
                
                self.value = .farenheit(clampedValue)
            }
    }
    
    var body: some View {
        Text("\(self.value.value())º F")
            .font(.title)
            .fontWeight(.medium)
            .frame(width: 110,
                   height: 48,
                   alignment: .center)
            .scaleEffect(self.dragging ? 1.2 : 1)
            .hoverEffect()
            .animation(.easeInOut(duration: 0.1), value: self.dragging)
            .gesture(self.drag)
    }
}

struct VolcanoControllerView_Previews: PreviewProvider {
    static var previews: some View {
        VolcanoControllerView()
    }
}
