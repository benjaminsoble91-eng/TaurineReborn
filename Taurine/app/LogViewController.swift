//
//  LogViewController.swift
//  Odyssey
//
//  Created by CoolStar on 7/1/20.
//  Copyright © 2020 coolstar. All rights reserved.
//
//  Taurine Reborn: the log is appended incrementally instead of replacing (and
//  re-styling) the whole text view on every chunk, auto-scroll only happens when
//  you're already at the bottom, and there's a Copy button.
//
import UIKit

class LogViewController: UIViewController {
    @IBOutlet var textView: UITextView!

    private var renderedLength = 0
    private let copyButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()

        isModalInPresentation = true

        textView.isEditable = false
        textView.text = ""   // clear the storyboard placeholder ("Log Window Here")
        textView.font = LogStream.logFont
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 24, right: 12)
        textView.layoutManager.allowsNonContiguousLayout = true
        textView.alwaysBounceVertical = true
        textView.indicatorStyle = .white

        setupCopyButton()

        NotificationCenter.default.addObserver(self, selector: #selector(LogViewController.reload), name: LogStream.shared.reloadNotification, object: nil)
        self.reload()
    }

    private func setupCopyButton() {
        copyButton.setTitle("Copy", for: .normal)
        copyButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        copyButton.tintColor = .white
        copyButton.backgroundColor = UIColor(white: 1, alpha: 0.15)
        copyButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        copyButton.layer.cornerRadius = 15
        copyButton.layer.cornerCurve = .continuous
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.addTarget(self, action: #selector(copyLog), for: .touchUpInside)
        view.addSubview(copyButton)
        NSLayoutConstraint.activate([
            copyButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            copyButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -14)
        ])
    }

    @objc private func copyLog() {
        UIPasteboard.general.string = LogStream.shared.outputString.string
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        copyButton.setTitle("Copied", for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.copyButton.setTitle("Copy", for: .normal)
        }
    }

    private var isNearBottom: Bool {
        let visibleBottom = textView.contentOffset.y + textView.bounds.height - textView.adjustedContentInset.bottom
        return textView.contentSize.height - visibleBottom < 80
    }

    @objc func reload() {
        guard let newText = LogStream.shared.text(since: renderedLength) else {
            return
        }
        let shouldFollow = renderedLength == 0 || isNearBottom
        ObjcTryCatch {
            self.textView.textStorage.append(newText)
            self.renderedLength += newText.length
            if shouldFollow, self.textView.textStorage.length > 0 {
                self.textView.scrollRangeToVisible(NSRange(location: self.textView.textStorage.length - 1, length: 1))
            }
        }
    }
}
