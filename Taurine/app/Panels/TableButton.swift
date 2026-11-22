//
//  TableButton.swift
//  Odyssey
//
//  Created by CoolStar on 7/5/20.
//  Copyright © 2020 coolstar. All rights reserved.
//

import UIKit

class TableButton: UIControl {
    // Taurine Reborn: highlight fades out instead of snapping, and disabled rows look disabled.
    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            if isHighlighted {
                self.backgroundColor = UIColor(white: 1, alpha: 0.22)
            } else {
                UIView.animate(withDuration: 0.25, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                    self.backgroundColor = UIColor.clear
                }
            }
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1 : 0.45
        }
    }
}
