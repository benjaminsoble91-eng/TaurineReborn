//
//  AppVersionManager.swift
//  Odyssey
//
//  Created by 23 Aaron on 16/08/2020.
//  Copyright © 2020 coolstar. All rights reserved.
//

import Foundation
import UIKit

private struct LatestVersionStruct: Decodable {
    let versionNumber: String
    let latestBlog: URL
    let downloadLink: URL
}

enum AVMError: Error {
    case noData
    case inaccessabileCurrentVerison
}

private let latestReleaseURL = URL(string: "https://taurine.app/api/latest-release.json")!

final class AppVersionManager {
    static let shared = AppVersionManager()
    private var cachedLatestVersion: LatestVersionStruct?
    
    private init() {}
    
    func doesApplicationRequireUpdate(_ completion: @escaping ((Result<Bool, Error>) -> Void)) {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            completion(.failure(AVMError.inaccessabileCurrentVerison))
            return
        }
        var request = URLRequest(url: latestReleaseURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            do {
                if let error = error {
                    throw error
                }
            
                guard let data = data else {
                    throw AVMError.noData
                }
                
                let currentRelease = try JSONDecoder().decode(LatestVersionStruct.self, from: data)
                self.cachedLatestVersion = currentRelease
            
                // Taurine Reborn: numeric compare ("1.1.10" > "1.1.7"); plain string compare got this wrong.
                let needsUpdate = currentVersion.compare(currentRelease.versionNumber, options: .numeric) == .orderedAscending
                completion(.success(needsUpdate))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func launchBestUpdateApplication() {
        guard let downloadLinkURL = cachedLatestVersion?.downloadLink,
              let percentEncodedString = downloadLinkURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        
        let altstoreURL = URL(string: "altstore://install?url=\(percentEncodedString)")!
        UIApplication.shared.open(altstoreURL, options: [:]) { success in
            if !success {
                guard let latestBlogURL = self.cachedLatestVersion?.latestBlog else{
                    return
                }
                UIApplication.shared.open(latestBlogURL, options: [:])
            }
        }
    }
}
