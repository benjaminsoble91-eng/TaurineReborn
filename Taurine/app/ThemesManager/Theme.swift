//
//  File.swift
//  Odyssey
//
//  Created by CoolStar on 7/6/20.
//  Copyright © 2020 coolstar. All rights reserved.
//

import UIKit

class Theme {
    let colorViewBackgrounds: [AnimatingColourView.GradientBackground]
    /// Asset name of the wallpaper. Loaded on first use instead of at launch
    /// (the original decoded all four wallpaper HEICs as soon as the app opened).
    let backgroundImageName: String?
    private(set) lazy var backgroundImage: UIImage? = backgroundImageName.flatMap { UIImage(named: $0) }
    let backgroundCenter: CGPoint
    let backgroundOverlay: UIColor?
    let progressGradientColors: [UIColor]?
    let progressGradientDelta: CGFloat
    let enableBlur: Bool
    let copyrightString: String
    
    init(colorViewBackgrounds: [AnimatingColourView.GradientBackground],
         backgroundImageName: String?,
         backgroundCenter: CGPoint = .zero,
         backgroundOverlay: UIColor?,
         progressGradientColors: [UIColor]? = nil,
         progressGradientDelta: CGFloat = 0.15,
         enableBlur: Bool,
         copyrightString: String = "") {
        self.colorViewBackgrounds = colorViewBackgrounds
        self.backgroundImageName = backgroundImageName
        self.backgroundCenter = backgroundCenter
        self.backgroundOverlay = backgroundOverlay
        self.progressGradientColors = progressGradientColors
        self.progressGradientDelta = progressGradientDelta
        self.enableBlur = enableBlur
        self.copyrightString = copyrightString
    }
}
