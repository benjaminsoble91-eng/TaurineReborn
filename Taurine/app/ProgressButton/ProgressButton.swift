//
//  ProgressButton.swift
//  taurine
//
//  Created by CoolStar on 3/14/21.
//

import UIKit

class ProgressButton: UIButton {
    let progressView: ProgressFill
    let progressLabel: ProgressLabel
    
    let defaultGradientColors = [
        UIColor(white: 1, alpha: 0.5),
        UIColor(white: 1, alpha: 0.6),
        UIColor(white: 1, alpha: 0.5)
    ]
    let defaultGradientDelta = CGFloat(0.15)
    
    required init?(coder: NSCoder) {
        progressView = ProgressFill(frame: .zero)
        //progressView.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
        progressView.setGradient(colors: defaultGradientColors, delta: defaultGradientDelta)
        
        progressLabel = ProgressLabel(frame: .zero)
        
        super.init(coder: coder)
        self.addSubview(progressView)
        self.addSubview(progressLabel)
        
        progressLabel.title = self.titleLabel?.text
        progressLabel.titleColor = self.titleLabel?.textColor
        progressLabel.font = self.titleLabel?.font
        progressLabel.isUserInteractionEnabled = false
        
        self.titleLabel?.alpha = 0
        
        // Taurine Reborn: smoother corners + clip the fill to them.
        layer.cornerCurve = .continuous
        clipsToBounds = true
        progressLabel.contentMode = .redraw
        
        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchDragExit, .touchCancel])
    }
    
    @objc private func touchDown() {
        UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            self.alpha = 0.85
        }
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.transform = .identity
            self.alpha = 1
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            // Keep the label readable when disabled (e.g. "Jailbroken", "Unsupported").
            progressLabel.alpha = isEnabled ? 1 : 0.75
        }
    }
    
    public func setGradient(colors: [UIColor]?, delta: CGFloat){
        let colors = colors ?? defaultGradientColors
        progressView.setGradient(colors: colors, delta: delta)
    }
    
    private var _progress: CGFloat = 0
    public var progress: CGFloat {
        get {
            _progress
        }
        set {
            _progress = newValue
            progressLabel.progress = newValue
            
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
    
    public func setProgress(_ progress: CGFloat, animated: Bool){
        _progress = progress
        progressLabel.progress = progress
        
        setNeedsLayout()
        guard animated else {
            layoutIfNeeded()
            return
        }
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.3,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.layoutIfNeeded()
        }
    }
    
    override func setTitleColor(_ color: UIColor?, for state: UIControl.State) {
        super.setTitleColor(color, for: state)
        if state == .normal {
            progressLabel.titleColor = color
        }
    }
    
    override func setTitle(_ title: String?, for state: UIControl.State) {
        super.setTitle(title, for: state)
        if state == .normal {
            guard progressLabel.title != title else { return }
            progressLabel.title = title
            // Quick crossfade so status changes don't just snap.
            UIView.transition(with: progressLabel, duration: 0.2, options: [.transitionCrossDissolve, .allowUserInteraction], animations: {
                self.progressLabel.setNeedsDisplay()
            }, completion: nil)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.titleLabel?.alpha = 0
        progressView.frame = CGRect(origin: .zero, size: CGSize(width: self.bounds.width * progress, height: self.bounds.height))
        if progressLabel.frame != bounds {
            progressLabel.frame = bounds
        }
        
        progressLabel.setNeedsDisplay()
    }
}
