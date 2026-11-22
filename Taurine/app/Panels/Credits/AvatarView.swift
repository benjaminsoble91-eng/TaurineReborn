//
//  AvatarView.swift
//  Chimera
//
//  Created by Ayden Panhuyzen on 2019-04-13.
//  Copyright © 2019 Electra Team. All rights reserved.
//
//  This file was taken from another project, and it’s inclusion here does not indicate the author’s endorsement.
//
//  Taurine Reborn:
//   - Avatars are fetched only when the Credits panel is opened (loadIfNeeded()),
//     not for all 7 people every launch while the panel is hidden.
//   - Shared in-memory cache, so re-entering the window never refetches.
//   - Images are downscaled + decoded off the main thread.
//   - Fixed the stale-request check (it compared the URL to itself, so it never worked).

import UIKit

class AvatarView: UIImageView {
    private static let cache = NSCache<NSURL, UIImage>()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 2 * 1024 * 1024, diskCapacity: 8 * 1024 * 1024, diskPath: "avatars")
        return URLSession(configuration: config)
    }()

    private var task: URLSessionDataTask?
    @IBInspectable var github: String = ""

    private var avatarURL: URL? {
        github.isEmpty ? nil : URL(string: "https://github.com/\(github).png?size=120")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        backgroundColor = UIColor(white: 1, alpha: 0.12)
        layer.borderColor = UIColor(white: 1, alpha: 0.25).cgColor
        clipsToBounds = true
        layer.borderWidth = 1 / (window?.screen.scale ?? 1)

        // Cached? Show it immediately. Otherwise wait until the panel is actually shown.
        if image == nil, let url = avatarURL, let cached = AvatarView.cache.object(forKey: url as NSURL) {
            image = cached
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.size.width, bounds.size.height) / 2
    }

    /// Starts the download if the avatar isn't loaded yet.
    func loadIfNeeded() {
        guard image == nil, task == nil else { return }
        url = avatarURL
    }

    var url: URL? {
        didSet {
            guard url != oldValue else { return }
            task?.cancel()
            task = nil
            guard let url = url else { image = nil; return }

            if let cached = AvatarView.cache.object(forKey: url as NSURL) {
                image = cached
                return
            }
            image = nil

            let start = DispatchTime.now()
            let maxPixels = max(bounds.width, bounds.height, 40) * (window?.screen.scale ?? 3)
            task = AvatarView.session.dataTask(with: url) { [weak self] data, _, error in
                guard let data = data, error == nil, let raw = UIImage(data: data) else {
                    if (error as NSError?)?.code != NSURLErrorCancelled {
                        print("Couldn't load avatar image due to error:", error ?? "unknown")
                    }
                    DispatchQueue.main.async { self?.task = nil }
                    return
                }
                let image = ImageProcess.decoded(raw, maxPixelSize: maxPixels)
                AvatarView.cache.setObject(image, forKey: url as NSURL)
                let tookLong = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds >= 150_000_000
                DispatchQueue.main.async {
                    guard let self = self, self.url == url else { return } // still the avatar we want?
                    self.task = nil
                    self.change(image: image, animated: tookLong)
                }
            }
            task?.priority = URLSessionTask.lowPriority
            task?.resume()
        }
    }

    private func change(image: UIImage, animated: Bool = true) {
        UIView.transition(with: self, duration: animated ? 0.3 : 0, options: [.allowAnimatedContent, .transitionCrossDissolve], animations: {
            self.image = image
        }, completion: nil)
    }
}

extension UIView {
    /// Kicks off avatar downloads for every AvatarView inside this view.
    func loadAvatarsIfNeeded() {
        if let avatar = self as? AvatarView {
            avatar.loadIfNeeded()
        }
        subviews.forEach { $0.loadAvatarsIfNeeded() }
    }
}
