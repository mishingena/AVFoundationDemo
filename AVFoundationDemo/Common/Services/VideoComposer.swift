//
//  MediaComposer.swift
//  AVFoundationDemo
//
//  Created by Gennadiy Mishin on 15.09.2020.
//  Copyright © 2020 GM. All rights reserved.
//

import UIKit
import AVFoundation

class VideoComposer {
    
    enum Constants {
        static let fadeTransitionDuration = CMTimeMake(value: 2, timescale: 1) // 2 sec
    }
    
    private(set) var composition = AVMutableComposition()
    private(set) var videoComposition = AVMutableVideoComposition()
    private(set) var error: Error?
    
    private var compositionVideoTracks: [AVCompositionTrack] {
        return composition.tracks(withMediaType: .video)
    }
    
    func composeMediaItemsWithFadeTransition(urls: [URL], keepAudio: Bool = true) {
        guard !urls.isEmpty else { return }
        
        composition = AVMutableComposition()
        let assets = urls.map { AVAsset(url: $0) }
        prepareVideoCompositionTracks(assets: assets)
        if keepAudio {
            prepareAudioCompositionTracks(assets: assets)
        }
        
        videoComposition = AVMutableVideoComposition(propertiesOf: composition)
        videoComposition.instructions = createCompositionInstructions(assets: assets)
        if let firstVideoTrack = assets.first?.videoTrack() {
            videoComposition.renderSize = firstVideoTrack.naturalSize
        }
    }
    
    private func prepareVideoCompositionTracks(assets: [AVAsset]) {
        let leadingVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let trailingVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)

        var cursorTime = CMTime.zero
        for (idx, asset) in assets.enumerated() {
            let assetTimeRange = CMTimeRangeMake(start: CMTime.zero, duration: asset.duration)
            let isLeadingTrack = idx % 2 == 0
            
            let currentVideoTrack = isLeadingTrack ? leadingVideoTrack : trailingVideoTrack
            error = currentVideoTrack?.insert(track: asset.videoTrack(), timeRange: assetTimeRange, at: cursorTime)
            
            cursorTime = CMTimeAdd(cursorTime, asset.duration)
            if asset.duration >= Constants.fadeTransitionDuration {
                // overlap clips by tranition duration
                cursorTime = CMTimeSubtract(cursorTime, Constants.fadeTransitionDuration)
            }
        }
    }
    
    private func prepareAudioCompositionTracks(assets: [AVAsset]) {
        var leadingAudioTrack: AVMutableCompositionTrack?
        var trailingAudioTrack: AVMutableCompositionTrack?
        
        var cursorTime = CMTime.zero
        for (idx, asset) in assets.enumerated() {
            let assetTimeRange = CMTimeRangeMake(start: CMTime.zero, duration: asset.duration)
            let isLeadingTrack = idx % 2 == 0
            
            if let assetAudioTrack = asset.audioTrack() {
                var currentAudioTrack: AVMutableCompositionTrack?
                if isLeadingTrack {
                    if leadingAudioTrack == nil {
                        leadingAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    }
                    currentAudioTrack = leadingAudioTrack
                } else {
                    if trailingAudioTrack == nil {
                        trailingAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    }
                    currentAudioTrack = trailingAudioTrack
                }
                error = currentAudioTrack?.insert(track: assetAudioTrack, timeRange: assetTimeRange, at: cursorTime)
            }
            
            cursorTime = CMTimeAdd(cursorTime, asset.duration)
            if asset.duration >= Constants.fadeTransitionDuration {
                // overlap clips by tranition duration
                cursorTime = CMTimeSubtract(cursorTime, Constants.fadeTransitionDuration)
            }
        }
    }
    
    private func createCompositionInstructions(assets: [AVAsset]) -> [AVMutableVideoCompositionInstruction] {
        var compositionInstructions = [AVMutableVideoCompositionInstruction]()

        let leadingVideoTrack = compositionVideoTracks.first
        let trailingVideoTrack = compositionVideoTracks.last
        
        let renderSize = assets.first?.videoTrack()?.naturalSize
        
        var cursorTime = CMTime.zero
        for (idx, asset) in assets.enumerated() {
            let isLeadingTrack = idx % 2 == 0
            let canInsertTransition = asset.duration > Constants.fadeTransitionDuration
            
            let instructionTimeRange = videoInstructionTimeRange(start: cursorTime,
                                                                 duration: asset.duration,
                                                                 isFirstTrack: idx == 0,
                                                                 isLastTrack: idx + 1 == assets.count)
            
            cursorTime = CMTimeAdd(cursorTime, asset.duration)
            if canInsertTransition {
                cursorTime = CMTimeSubtract(cursorTime, Constants.fadeTransitionDuration)
            }
            
            if let fromVideoTrack = isLeadingTrack ? leadingVideoTrack : trailingVideoTrack {
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = instructionTimeRange
                
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: fromVideoTrack)
                if let assetVideoTrack = asset.videoTrack() {
                    if let renderSize = renderSize {
                        layerInstruction.setTransform(fitTransform(size: assetVideoTrack.naturalSize, renderSize: renderSize), at: instructionTimeRange.start)
                    } else {
                        layerInstruction.setTransform(assetVideoTrack.preferredTransform, at: instructionTimeRange.start)
                    }
                }
                instruction.layerInstructions = [layerInstruction]
                
                compositionInstructions.append(instruction)
                
                if canInsertTransition, idx + 1 < assets.count, let toVideoTrack = isLeadingTrack ? trailingVideoTrack : leadingVideoTrack {
                    let fromAssetVideoTrack = asset.videoTrack()
                    let toAssetVideoTrack = assets[idx + 1].videoTrack()
                    let instruction = videoFadeTransitionInstruction(at: cursorTime,
                                                                     fromTrack: fromVideoTrack,
                                                                     toTrack: toVideoTrack,
                                                                     renderSize: renderSize,
                                                                     fromVideoTrack: fromAssetVideoTrack,
                                                                     toVideoTrack: toAssetVideoTrack)
                    compositionInstructions.append(instruction)
                }
            }
        }
        return compositionInstructions
    }
    
    private func videoInstructionTimeRange(start: CMTime, duration: CMTime, isFirstTrack: Bool, isLastTrack: Bool) -> CMTimeRange {
        var timeRange = CMTimeRangeMake(start: start, duration: duration)
        if duration > Constants.fadeTransitionDuration {
            if !isFirstTrack {
                timeRange.start = CMTimeAdd(timeRange.start, Constants.fadeTransitionDuration)
                timeRange.duration = CMTimeSubtract(timeRange.duration, Constants.fadeTransitionDuration)
            }
            if !isLastTrack {
                timeRange.duration = CMTimeSubtract(timeRange.duration, Constants.fadeTransitionDuration)
            }
        }
        return timeRange
    }
    
    private func videoFadeTransitionInstruction(at time: CMTime,
                                                fromTrack: AVCompositionTrack,
                                                toTrack: AVCompositionTrack,
                                                renderSize: CGSize?,
                                                fromVideoTrack: AVAssetTrack?,
                                                toVideoTrack: AVAssetTrack?) -> AVMutableVideoCompositionInstruction {
        let timeRange = CMTimeRangeMake(start: time, duration: Constants.fadeTransitionDuration)
        
        let fromLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: fromTrack)
        fromLayerInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: timeRange)

        let toLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: toTrack)
        toLayerInstruction.setOpacityRamp(fromStartOpacity: 0.0, toEndOpacity: 1.0, timeRange: timeRange)
        
        if let fromVideoTrack = fromVideoTrack, let toVideoTrack = toVideoTrack {
            if let renderSize = renderSize {
                fromLayerInstruction.setTransform(fitTransform(size: fromVideoTrack.naturalSize, renderSize: renderSize), at: timeRange.start)
                toLayerInstruction.setTransform(fitTransform(size: toVideoTrack.naturalSize, renderSize: renderSize), at: timeRange.start)
            } else {
                toLayerInstruction.setTransform(toVideoTrack.preferredTransform, at: .zero)
                fromLayerInstruction.setTransform(fromVideoTrack.preferredTransform, at: .zero)
            }
        }
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        instruction.layerInstructions = [fromLayerInstruction, toLayerInstruction]
        
        return instruction
    }
    
    private func fitTransform(size: CGSize, renderSize: CGSize) -> CGAffineTransform {
        let fitSize = size.aspectFit(size: renderSize)
        let scaleTransform = CGAffineTransform(scaleX: fitSize.width / size.width,
                                               y: fitSize.height / size.height)
        let transaltionTransform = CGAffineTransform(translationX: (renderSize.width - fitSize.width) * 0.5,
                                                     y: (renderSize.height - fitSize.height) * 0.5)
        return scaleTransform.concatenating(transaltionTransform)
    }
}
