//
//  PiPVideoComposer.swift
//  AVFoundationDemo
//
//  Created by Gennadiy Mishin on 16.09.2020.
//  Copyright © 2020 GM. All rights reserved.
//

import UIKit
import AVFoundation

class PiPVideoComposer: NSObject {

    private(set) var composition = AVMutableComposition()
    private(set) var videoComposition = AVMutableVideoComposition()
    
    private var compositionVideoTracks: [AVCompositionTrack] {
        return composition.tracks(withMediaType: .video)
    }
    
    func composeMediaItems(mainVideoURL: URL, pictureVideoURL: URL, keepAudio: Bool = true) {
        composition = AVMutableComposition()
        let mainVideoAsset = AVAsset(url: mainVideoURL)
        let pictureVideoAsset = AVAsset(url: pictureVideoURL)
        prepareVideoCompositionTrack(mainVideoAsset: mainVideoAsset, pictureVideoAsset: pictureVideoAsset)
        if keepAudio {
            prepareAudioCompositionTracks(mainVideoAsset: mainVideoAsset, pictureVideoAsset: pictureVideoAsset)
        }
        
        videoComposition = AVMutableVideoComposition(propertiesOf: composition)
        videoComposition.instructions = createCompositionInstructions(mainVideoAsset: mainVideoAsset, pictureVideoAsset: pictureVideoAsset)
        if let mainVideoTrack = mainVideoAsset.videoTrack() {
            videoComposition.renderSize = mainVideoTrack.naturalSize
        }
    }
    
    private func prepareVideoCompositionTrack(mainVideoAsset: AVAsset, pictureVideoAsset: AVAsset) {
        let mainVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let pictureVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let mainTimeRange = CMTimeRangeMake(start: CMTime.zero, duration: mainVideoAsset.duration)
        mainVideoTrack?.insert(track: mainVideoAsset.videoTrack(),
                           timeRange: mainTimeRange,
                           at: .zero)
        
        let pictureTimeRange = CMTimeRangeMake(start: CMTime.zero, duration: pictureVideoAsset.duration)
        pictureVideoTrack?.insert(track: pictureVideoAsset.videoTrack(),
                               timeRange: pictureTimeRange,
                               at: .zero)
    }
    
    private func prepareAudioCompositionTracks(mainVideoAsset: AVAsset, pictureVideoAsset: AVAsset) {
        if let assetPictureAudioTrack = pictureVideoAsset.audioTrack() {
            let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            let timeRange = CMTimeRangeMake(start: CMTime.zero, duration: pictureVideoAsset.duration)
            audioTrack?.insert(track: assetPictureAudioTrack, timeRange: timeRange, at: .zero)
        }
    }
    
    private func createCompositionInstructions(mainVideoAsset: AVAsset, pictureVideoAsset: AVAsset) -> [AVMutableVideoCompositionInstruction] {
        var compositionInstructions = [AVMutableVideoCompositionInstruction]()

        let mainVideoTrack = compositionVideoTracks.first
        let pictureVideoTrack = compositionVideoTracks.last
        
        if let mainVideoTrack = mainVideoTrack {
            let mainLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: mainVideoTrack)
            mainLayerInstruction.setOpacity(0.0, at: mainVideoAsset.duration)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: max(mainVideoAsset.duration, pictureVideoAsset.duration))
            instruction.backgroundColor = UIColor.black.cgColor
            
            if let pictureVideoTrack = pictureVideoTrack {
                let pictureLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: pictureVideoTrack)
                
                let pictureFitSize = pictureVideoTrack.naturalSize.aspectFit(size: mainVideoTrack.naturalSize)
                let pictureSize = CGSize(width: pictureFitSize.width * 0.5, height: pictureFitSize.height * 0.5)
                
                let scaleTransform = CGAffineTransform(scaleX: pictureSize.width / pictureVideoTrack.naturalSize.width,
                                                       y: pictureSize.height / pictureVideoTrack.naturalSize.height)
                let transaltionTransform = CGAffineTransform(translationX: 0,
                                                             y: mainVideoTrack.naturalSize.height - pictureSize.height)
                let transform = scaleTransform.concatenating(transaltionTransform)
                pictureLayerInstruction.setTransform(transform, at: .zero)
                
                let fadeDuration = CMTime(value: 1, timescale: 1) // 1 sec
                if pictureVideoAsset.duration > fadeDuration {
                    let timeRange = CMTimeRange(start: CMTimeSubtract(pictureVideoAsset.duration, fadeDuration), duration: fadeDuration)
                    pictureLayerInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: timeRange)
                } else {
                    pictureLayerInstruction.setOpacity(0.0, at: pictureVideoAsset.duration)
                }
                
                
                instruction.layerInstructions = [pictureLayerInstruction, mainLayerInstruction]
            } else {
                instruction.layerInstructions = [mainLayerInstruction]
            }
            
            compositionInstructions.append(instruction)
        }
        
        return compositionInstructions
    }
}
