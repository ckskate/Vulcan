//
//  AnimatedVolcanoView.swift
//  Vulcan
//
//  Created by Connor Killion on 11/29/21.
//

import SwiftUI

final class SmokeStream: ObservableObject {
    var segmentLocations: [CGPoint]
    var opacity: CGFloat = 1.0
    var expansionFactor: CGFloat = 0.0
    
    private(set) var startingPoint: CGPoint
    private var length: Int
    private var spacing: CGFloat
    
    init(segmentLocations: [CGPoint], 
         startingPoint: CGPoint, 
         length: Int, 
         spacing: CGFloat) {
        self.segmentLocations = segmentLocations
        self.startingPoint = startingPoint
        self.length = length
        self.spacing = spacing
    }
    
    static func create(startingPoint: CGPoint, 
                       length: Int = 70, 
                       spacing: CGFloat = 2) -> SmokeStream {
        var locations = [CGPoint]()
        for i in 0..<length {
            locations.append(CGPoint(x: startingPoint.x,
                                     y: startingPoint.y - (CGFloat(i) * spacing)))
        }
        return SmokeStream(segmentLocations: locations,
                           startingPoint: startingPoint,
                           length: length,
                           spacing: spacing)
    }
    
    func reset(to point: CGPoint) {
        self.startingPoint = point
        var locations = [CGPoint]()
        for i in 0..<length {
            locations.append(CGPoint(x: startingPoint.x,
                                     y: startingPoint.y - (CGFloat(i) * spacing)))
        }
        self.segmentLocations = locations
        self.opacity = 1.0
        self.expansionFactor = 0.0
    }
    
    func advance(to time: Date) {
        for (i, location) in self.segmentLocations.enumerated() {
            let distanceFromStart = self.startingPoint.y - location.y - 100
            let expander: CGFloat = self.expansionFactor 
                                    * (distanceFromStart / 50) 
                                    * (CGFloat(i) / CGFloat(self.length))
            let wiggleSpeedFactor: CGFloat = 2.5 - (self.expansionFactor / 10000000000)
            let multiplier: CGFloat = min(expander, 25) 
                                    * sin((((time.timeIntervalSinceReferenceDate * wiggleSpeedFactor) 
                                            + (CGFloat(i) / 5)).remainder(dividingBy: 2 * .pi)))
            let slowDownFactor: CGFloat = 0.25 
                                        * (1 - ((self.expansionFactor / 22) 
                                              * (CGFloat(i) / 60)))
            self.segmentLocations[i] = CGPoint(x: self.startingPoint.x + multiplier,
                                               y: location.y - slowDownFactor)
        }
        self.opacity -= 0.001
        self.expansionFactor += 0.01
    }
    
    var asPath: Path {
        let path = CGMutablePath()
        guard let firstLocation = self.segmentLocations.first else {
            return Path()
        }
        path.move(to: firstLocation)
        for segmentLocation in segmentLocations.suffix(from: 1) {
            path.addLine(to: segmentLocation)
        }
        return Path(path)
    }
}

struct AnimatedVolcanoView: View {
    
    @StateObject private var smoke = SmokeStream.create(startingPoint: .zero)
    let isAnimating: Bool
    
    var body: some View {
        TimelineView(.animation) { timelineCtx in
            Canvas { context, size in
                if self.smoke.opacity <= 0.0 
                    || self.smoke.startingPoint == .zero
                    || self.isAnimating == false {
                    self.smoke.reset(to: CGPoint(x: (size.width * 0.5) - 1,
                                                 y: (size.height + 50)))
                }
                
                let image = Image(systemName: "triangle")
                context.draw(image,
                             in: CGRect(origin: CGPoint(x: (size.width * 0.5) - 50,
                                                        y: (size.height) - 100),
                                        size: CGSize(width: 100, height: 100)))
                context.clip(to: Path(CGRect(origin: CGPoint(x: (size.width * 0.5) - 100, 
                                                             y: (size.height - 405)),
                                             size: CGSize(width: 200, 
                                                          height: 300)
                                            )
                                     )
                )
                if self.isAnimating {
                    context.opacity = smoke.opacity
                    context.stroke(smoke.asPath, 
                                   with: .color(Color.primary), 
                                   style: StrokeStyle(lineWidth: 8, 
                                                      lineCap: CGLineCap.round, 
                                                      lineJoin: CGLineJoin.round))
                    self.smoke.advance(to: timelineCtx.date)
                }
            }
        }
    }
}

struct AnimatedVolcanoView_Previews: PreviewProvider {
    static var previews: some View {
        AnimatedVolcanoView(isAnimating: true)
    }
}
