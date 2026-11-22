//
//  SeparatorView.swift
//  odysseyjb
//
//  Created by Hayden Seay on 6/24/20.
//  Copyright © 2020 Coolstar Org. All rights reserved.
//

import UIKit

class SeparatorView: UIView {

	override func didMoveToWindow() {
		super.didMoveToWindow()

		// Taurine Reborn: window can be nil (view leaving the hierarchy) — the original force-unwrapped it.
		guard let scale = window?.screen.scale, scale > 0 else { return }
		if let constraint = constraints.first(where: { $0.firstAttribute == .height || $0.secondAttribute == .height }) {
			constraint.constant = 1 / scale
		}
	}

}
