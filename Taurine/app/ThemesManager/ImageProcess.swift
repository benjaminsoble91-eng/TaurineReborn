//
//  ImageProcess.swift
//  Odyssey
//
//  Created by CoolStar on 7/6/20.
//  Copyright © 2020 coolstar. All rights reserved.
//

import UIKit

class ImageProcess {
    
    public class func sizeImage(image: UIImage, aspectHeight: CGFloat, aspectWidth: CGFloat, center: CGPoint) -> UIImage? {
        let aspectRatio = aspectHeight / aspectWidth
        
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        let imageAspectRatio = imageSize.height / imageSize.width
        
        let largestSize = (imageAspectRatio > aspectRatio) ?
            CGSize(width: imageSize.width, height: aspectRatio * imageSize.width) :
            CGSize(width: imageSize.height / aspectRatio, height: imageSize.height)
        
        var cropRect = CGRect(origin: .zero, size: largestSize)
        if largestSize.height == imageSize.height {
            cropRect.origin.x = center.x - (largestSize.width / 2)
            
            cropRect.origin.y = 0
            
            if cropRect.origin.x < 0 {
                cropRect.origin.x = 0
            }
            if cropRect.origin.x + cropRect.size.width > imageSize.width {
                cropRect.origin.x = imageSize.width - cropRect.size.width
            }
        } else {
            cropRect.origin.x = 0
            
            cropRect.origin.y = center.y - (largestSize.height / 2)
            
            if cropRect.origin.y < 0 {
                cropRect.origin.y = 0
            }
            if cropRect.origin.y + cropRect.size.height > imageSize.height {
                cropRect.origin.y = imageSize.height - cropRect.size.height
            }
        }
        
        if let croppedImage = cgImage.cropping(to: cropRect) {
            return UIImage(cgImage: croppedImage)
        }
        return nil
    }
    
    // MARK: - Taurine Reborn
    
    private static let workQueue = DispatchQueue(label: "taurine.reborn.imageprocess", qos: .userInitiated)
    
    /// Redraws `image` at (at most) `maxPixelSize` on its longest side. This forces the
    /// HEIC/PNG to be decoded here, off the main thread, instead of lazily on the main
    /// thread during the first frame, and stops a 3000px wallpaper from being blurred
    /// at full resolution behind the UI.
    class func decoded(_ image: UIImage, maxPixelSize: CGFloat) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        let factor = longest > maxPixelSize && longest > 0 ? maxPixelSize / longest : 1
        let target = CGSize(width: floor(pixelSize.width * factor), height: floor(pixelSize.height * factor))
        guard target.width > 0, target.height > 0 else { return image }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
    
    /// Crops a theme wallpaper for the screen and decodes it in the background.
    class func prepareBackground(image: UIImage, aspectHeight: CGFloat, aspectWidth: CGFloat, center: CGPoint?,
                                 screenScale: CGFloat, completion: @escaping (UIImage?) -> Void) {
        workQueue.async {
            var result: UIImage? = image
            if let center = center {
                result = ImageProcess.sizeImage(image: image, aspectHeight: aspectHeight, aspectWidth: aspectWidth, center: center)
            }
            let maxPixels = max(aspectHeight, aspectWidth) * screenScale
            if let cropped = result {
                result = ImageProcess.decoded(cropped, maxPixelSize: maxPixels)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }
    
    /// Saves a picked custom wallpaper in the background, downscaled to screen size.
    class func saveCustomImage(_ image: UIImage, to url: URL, maxPixelSize: CGFloat, completion: @escaping (Bool) -> Void) {
        workQueue.async {
            let scaled = ImageProcess.decoded(image, maxPixelSize: maxPixelSize)
            var ok = false
            if let data = scaled.jpegData(compressionQuality: 0.92) ?? scaled.pngData() {
                ok = (try? data.write(to: url, options: .atomic)) != nil
            }
            DispatchQueue.main.async { completion(ok) }
        }
    }
}
