//
//  AnimatingColourView.swift
//  Chimera
//
//  Created by Ayden Panhuyzen on 2019-04-24.
//  Copyright © 2019 Electra Team. All rights reserved.
//
//  This file was taken from another project, and it’s inclusion here does not indicate the author’s endorsement.
//

import UIKit

class AnimatingColourView: UIView {
    private var gradientViewContainer = UIView()
    private var overlayImageView = UIImageView()
    
    struct GradientBackground {
        let baseColour: UIColor
        let linearGradients: [GradientView.Gradient]
        let overlayImage: UIImage?
    }
    
    private var backgroundsToUse: [AnimatingColourView.GradientBackground] {
        if UserDefaults.standard.string(forKey: "theme") == "customColourTheme" {
            return ThemesManager.shared.customColourBackground
        } else {
            return ThemesManager.shared.currentTheme.colorViewBackgrounds
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        gradientViewContainer.frame = bounds
        gradientViewContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(gradientViewContainer)
        
        setup(for: backgroundsToUse.first)
        rescheduleTimer()
        
        // Theme changes apply right away with a short fade (was a 4 second crossfade).
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: ThemesManager.themeChangeNotification, object: nil)
    }
    
    deinit {
        cycleTimer?.invalidate()
    }
    
    // Taurine Reborn: only cycle backgrounds when there is more than one to cycle
    // through. Every built-in theme has exactly one, so the original 10 second timer
    // tore down and rebuilt identical gradient views forever for no visual change.
    private var cycleTimer: Timer?
    
    private func rescheduleTimer() {
        cycleTimer?.invalidate()
        cycleTimer = nil
        guard backgroundsToUse.count > 1 else { return }
        cycleTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.tick()
        }
        cycleTimer?.tolerance = 2
    }
    
    @objc private func themeChanged() {
        UIView.transition(with: self, duration: 0.35, options: .transitionCrossDissolve, animations: {
            self.setup(for: self.backgroundsToUse.first)
        }, completion: nil)
        rescheduleTimer()
    }
    
    /// Freezes / unfreezes the moving gradients (used while the jailbreak runs so the
    /// GPU isn't busy re-blurring an animated background).
    func setAnimationsPaused(_ paused: Bool) {
        let layer = gradientViewContainer.layer
        if paused {
            guard layer.speed != 0 else { return }
            let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
            layer.speed = 0
            layer.timeOffset = pausedTime
        } else {
            guard layer.speed == 0 else { return }
            let pausedTime = layer.timeOffset
            layer.speed = 1
            layer.timeOffset = 0
            layer.beginTime = 0
            layer.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func tick() {
        guard backgroundsToUse.count > 1 else { return }
        UIView.transition(with: self, duration: 4, options: .transitionCrossDissolve, animations: {
            let backgrounds = self.backgroundsToUse
            self.setup(for: backgrounds.randomElement())
        }, completion: nil)
    }
    
    private func setup(for background: GradientBackground?) {
        backgroundColor = background?.baseColour
        gradientViewContainer.subviews.forEach { $0.removeFromSuperview() }
        guard let background = background else { return }
        for (index, gradient) in background.linearGradients.enumerated() {
            let view = GradientView(gradient: gradient)
            view.frame = gradientViewContainer.bounds
            view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            view.rotationAnimationSpeed = 1.0 / Double(index + 1)
            gradientViewContainer.addSubview(view)
        }
    }

    class GradientView: UIView {
        struct Gradient {
            typealias Stop = (colour: UIColor, position: Double)
            let stops: [Stop]
            /// Angle in degrees (0º means the gradient moves top to bottom)
            let angle: Double
            
            init(stops: [Stop], angle: Double = 0) {
                self.stops = stops
                self.angle = angle
            }
            
            init(colours: [UIColor], angle: Double = 0) {
                self.stops = colours.enumerated().map { (colour: $0.element, position: 1.0 / Double(colours.count - 1) * Double($0.offset)) }
                self.angle = angle
            }
        }
        
        private class _GradientView: UIView {
            init(gradient: Gradient) {
                super.init(frame: .zero)
                
                gradientLayer.colors = gradient.stops.map { $0.colour.cgColor }
                gradientLayer.locations = gradient.stops.map { NSNumber(value: $0.position) }
                
                let (start, end) = points(forAngle: gradient.angle)
                gradientLayer.startPoint = start
                gradientLayer.endPoint = end
            }
            
            required init?(coder aDecoder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override class var layerClass: AnyClass {
                CAGradientLayer.self
            }
            
            var gradientLayer: CAGradientLayer {
                //swiftlint:disable:next force_cast
                layer as! CAGradientLayer
            }
            
            private func points(forAngle angle: Double) -> (start: CGPoint, end: CGPoint) {
                // I'm too lazy to do math -- https://stackoverflow.com/a/44922976/5539613
                let angle = angle / 360
                let a = pow(sin(2 * Double.pi * (angle + 0.75) / 2), 2)
                let b = pow(sin(2 * Double.pi * angle / 2), 2)
                let c = pow(sin(2 * Double.pi * (angle + 0.25) / 2), 2)
                let d = pow(sin(2 * Double.pi * (angle + 0.5) / 2), 2)
                
                return (start: CGPoint(x: CGFloat(a), y: CGFloat(b)), end: CGPoint(x: CGFloat(c), y: CGFloat(d)))
            }
        }
        
        private let innerGradientView: _GradientView!, rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z"), scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        
        init(gradient: Gradient) {
            innerGradientView = _GradientView(gradient: gradient)
            super.init(frame: .zero)
        
            addSubview(innerGradientView)
            
            rotationAnimation.fromValue = 0
            rotationAnimation.toValue = CGFloat.pi * 2
            rotationAnimation.isRemovedOnCompletion = false
            rotationAnimation.fillMode = .forwards
            rotationAnimation.repeatCount = .infinity
            
            scaleAnimation.fromValue = 1
            scaleAnimation.toValue = 2
            scaleAnimation.autoreverses = true
            scaleAnimation.isRemovedOnCompletion = false
            scaleAnimation.fillMode = .forwards
            scaleAnimation.repeatCount = .infinity
            
            NotificationCenter.default.addObserver(self, selector: #selector(receivedApplicationStatus(notification:)), name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(receivedApplicationStatus(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(motionSettingsChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(motionSettingsChanged), name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        }
        
        @objc func receivedApplicationStatus(notification: Notification) {
            isInForeground = notification.name == UIApplication.didBecomeActiveNotification
        }
        
        @objc private func motionSettingsChanged() {
            DispatchQueue.main.async {
                self.animationsEnabled = self.isInForeground && !GradientView.prefersStaticBackground
            }
        }
        
        /// Reduce Motion or Low Power Mode → static gradient (no rotation/scale).
        static var prefersStaticBackground: Bool {
            UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        
        private var isInForeground = true {
            didSet { animationsEnabled = isInForeground && !GradientView.prefersStaticBackground }
        }
        
        // Taurine Reborn: only restart the animations when the size actually changes.
        // The original restarted them on *every* layout pass, which caused visible
        // jumps and wasted work whenever anything on screen re-laid out.
        private var lastAnimatedSize: CGSize = .zero
        
        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.size != lastAnimatedSize else { return }
            lastAnimatedSize = bounds.size
            setupAnimations()
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        var rotationAnimationSpeed: Double = 0 {
            didSet { setupAnimations() }
        }
        
        private var animationsEnabled: Bool = !GradientView.prefersStaticBackground {
            didSet {
                guard animationsEnabled != oldValue else { return }
                setupAnimations()
            }
        }
        
        private func setupAnimations() {
            innerGradientView.layer.removeAllAnimations()
            innerGradientView.transform = .identity
            innerGradientView.frame = bounds
            guard animationsEnabled, rotationAnimationSpeed > 0, bounds.width > 0, bounds.height > 0 else { return }
            
            // Durations are set first: the original read rotationAnimation.duration
            // before assigning it, so the first frame animation ran with duration 0.
            rotationAnimation.duration = 20 / rotationAnimationSpeed
            scaleAnimation.duration = rotationAnimation.duration / 8
            
            UIView.animate(withDuration: rotationAnimation.duration / 4, delay: 0, options: [.autoreverse, .repeat, .allowUserInteraction], animations: {
                let width = self.bounds.width
                let height = self.bounds.height
                self.innerGradientView.frame = CGRect(x: width / 2 - height / 2, y: height / 2 - width / 2, width: height, height: width)
            }, completion: nil)
            
            innerGradientView.layer.add(rotationAnimation, forKey: "rotation")
            innerGradientView.layer.add(scaleAnimation, forKey: "scale")
        }
    }

}
