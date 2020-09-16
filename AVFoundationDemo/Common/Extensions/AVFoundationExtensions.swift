//
//  AVFoundationExtensions.swift
//  AVFoundationDemo
//
//  Created by Gennadiy Mishin on 15.09.2020.
//  Copyright © 2020 GM. All rights reserved.
//

import AVFoundation
import UIKit

extension AVMutableCompositionTrack {
    
    @discardableResult
    func insert(track: AVAssetTrack?, timeRange: CMTimeRange, at time: CMTime) -> Error? {
        guard let track = track else { return nil }
        do {
            try insertTimeRange(timeRange, of: track, at: time)
        } catch let e {
            return e
        }
        return nil
    }
}

extension AVAsset {
    
    func audioTrack() -> AVAssetTrack? {
        return tracks(withMediaType: .audio).first
    }
    
    func videoTrack() -> AVAssetTrack? {
        return tracks(withMediaType: .video).first
    }
}

extension AVAsset {
    
    static func generatePreviewImage(assetURL: URL) -> UIImage? {
        let asset = AVAsset(url: assetURL)
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        assetImgGenerate.maximumSize = CGSize(width: 44.0, height: 44.0)
        let time = CMTimeMakeWithSeconds(1.0, preferredTimescale: 600)
        do {
            let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
            let thumbnail = UIImage(cgImage: img)
            return thumbnail
        } catch let e {
            debugPrint(e)
            return nil
        }
    }
}
