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
    
    private(set) var error: Error?
    var composition: AVComposition {
        return (mutableComposition.copy() as? AVComposition) ?? AVComposition()
    }
    var videoComposition: AVVideoComposition {
        return (mutableVideoComposition.copy() as? AVVideoComposition) ?? AVVideoComposition()
    }
    
    private var mutableComposition = AVMutableComposition()
    private var mutableVideoComposition = AVMutableVideoComposition()
    
    private var videoCompositionTrackA: AVMutableCompositionTrack?
    private var videoCompositionTrackB: AVMutableCompositionTrack?
    private var audioCompositionTrackA: AVMutableCompositionTrack?
    private var audioCompositionTrackB: AVMutableCompositionTrack?
    
    private var pipVideoCompositionTrack: AVMutableCompositionTrack?
    private var pipAudioCompositionTrack: AVMutableCompositionTrack?
    private var pipLayerInstruction: AVMutableVideoCompositionLayerInstruction?
    
    private var assets: [AVAsset] = []
    private var pipAsset: AVAsset?
    
    private var videoRenderSize: CGSize = .zero
    
    func composeMediaItemsWithFadeTransition(urls: [URL], pipURL: URL?) {
        guard !urls.isEmpty else { return }
        
        assets = urls.map { AVAsset(url: $0) }
        pipAsset = pipURL.map { AVAsset(url: $0) }
        
        videoRenderSize = assets.first?.videoTrack()?.naturalSize ?? .zero
        
        mutableComposition = AVMutableComposition()
        prepareVideoCompositionTracks()
        prepareAudioCompositionTracks()
        
        mutableVideoComposition = AVMutableVideoComposition(propertiesOf: mutableComposition)
        mutableVideoComposition.instructions = createVideoCompositionInstructions()
        mutableVideoComposition.renderSize = videoRenderSize
    }
    
    private func prepareVideoCompositionTracks() {
        if let pipAsset = pipAsset {
            let timeRange = CMTimeRangeMake(start: .zero, duration: pipAsset.duration)
            pipVideoCompositionTrack = mutableComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            pipVideoCompositionTrack?.insert(track: pipAsset.videoTrack(), timeRange: timeRange, at: .zero)
        }
        
        videoCompositionTrackA = mutableComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        videoCompositionTrackB = mutableComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var cursorTime = CMTime.zero
        for (idx, asset) in assets.enumerated() {
            let assetTimeRange = CMTimeRangeMake(start: CMTime.zero, duration: asset.duration)
            error = videoCompositionTrack(idx: idx)?.insert(track: asset.videoTrack(), timeRange: assetTimeRange, at: cursorTime)
            
            cursorTime = CMTimeAdd(cursorTime, asset.duration)
            if asset.duration > Constants.fadeTransitionDuration, idx + 1 < assets.count {
                // overlap clips by tranition duration
                cursorTime = CMTimeSubtract(cursorTime, Constants.fadeTransitionDuration)
            }
        }
    }
    
    private func prepareAudioCompositionTracks() {
        var cursorTime = CMTime.zero
        for (idx, asset) in assets.enumerated() {
            if let audioTrack = asset.audioTrack() {
                var currentAudioTrack: AVMutableCompositionTrack?
                if idx % 2 == 0 {
                    if audioCompositionTrackA == nil {
                        audioCompositionTrackA = mutableComposition.addMutableTrack(withMediaType: .audio,
                                                                             preferredTrackID: kCMPersistentTrackID_Invalid)
                    }
                    currentAudioTrack = audioCompositionTrackA
                } else {
                    if audioCompositionTrackB == nil {
                        audioCompositionTrackB = mutableComposition.addMutableTrack(withMediaType: .audio,
                                                                             preferredTrackID: kCMPersistentTrackID_Invalid)
                    }
                    currentAudioTrack = audioCompositionTrackB
                }
                let timeRange = CMTimeRangeMake(start: CMTime.zero, duration: asset.duration)
                error = currentAudioTrack?.insert(track: audioTrack, timeRange: timeRange, at: cursorTime)
            }
            
            cursorTime = CMTimeAdd(cursorTime, asset.duration)
            if asset.duration >= Constants.fadeTransitionDuration {
                // overlap clips by tranition duration
                cursorTime = CMTimeSubtract(cursorTime, Constants.fadeTransitionDuration)
            }
        }
        
        if let pipAsset = pipAsset {
            let timeRange = CMTimeRangeMake(start: .zero, duration: pipAsset.duration)
            if let audioTrack = pipAsset.audioTrack() {
                pipAudioCompositionTrack = mutableComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                error = pipAudioCompositionTrack?.insert(track: audioTrack, timeRange: timeRange, at: .zero)
            }
        }
    }
    
    private func videoCompositionTrack(idx: Int) -> AVMutableCompositionTrack? {
        return idx % 2 == 0 ? videoCompositionTrackA : videoCompositionTrackB
    }
    
    private func createVideoCompositionInstructions() -> [AVMutableVideoCompositionInstruction] {
        var compositionInstructions = [AVMutableVideoCompositionInstruction]()
        
        if let pipAsset = pipAsset, let pipVideoCompositionTrack = pipVideoCompositionTrack {
            pipLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: pipVideoCompositionTrack)
            pipLayerInstruction?.setTransform(pipTransform(size: pipVideoCompositionTrack.naturalSize, renderSize: videoRenderSize),
                                             at: .zero)
            pipLayerInstruction?.setOpacity(0.0, at: pipAsset.duration)
        }
        
        var cursorTime = CMTime.zero
        for (idx, asset) in assets.enumerated() {
            let canInsertTransition = asset.duration > Constants.fadeTransitionDuration
            
            let isPrevTrackTransition = idx > 0 ? assets[idx-1].duration > Constants.fadeTransitionDuration : false
            let instructionTimeRange = videoInstructionTimeRange(start: cursorTime,
                                                                 duration: asset.duration,
                                                                 isFirstTrack: idx == 0,
                                                                 isLastTrack: idx + 1 == assets.count,
                                                                 isPrevTrackTransition: isPrevTrackTransition)
            
            
            guard let currentVideoCompositionTrack = videoCompositionTrack(idx: idx) else { continue }
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = instructionTimeRange
            
            var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []
            
            if let pipLayerInstruction = pipLayerInstruction, let pipVideoCompositionTrack = pipVideoCompositionTrack {
                let pipEndTime = CMTimeAdd(pipVideoCompositionTrack.timeRange.start, pipVideoCompositionTrack.timeRange.duration)
                if pipEndTime >= cursorTime {
                    layerInstructions.append(pipLayerInstruction)
                }
            }
            
            if let videoTrack = asset.videoTrack() {
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: currentVideoCompositionTrack)
                layerInstruction.setTransform(aspectFitTransform(size: videoTrack.naturalSize, renderSize: videoRenderSize),
                                              at: instructionTimeRange.start)
                layerInstruction.setOpacity(0.0, at: CMTimeAdd(cursorTime, asset.duration))
                
                layerInstructions.append(layerInstruction)
            }
            
            instruction.layerInstructions = layerInstructions
            compositionInstructions.append(instruction)
            
            // next cursor
            cursorTime = CMTimeAdd(cursorTime, asset.duration)
            if canInsertTransition {
                cursorTime = CMTimeSubtract(cursorTime, Constants.fadeTransitionDuration)
            }
            
            if idx + 1 < assets.count, canInsertTransition, let nextVideoCompositionTrack = videoCompositionTrack(idx: idx + 1) {
                let fromAssetVideoTrack = asset.videoTrack()
                let toAssetVideoTrack = assets[idx + 1].videoTrack()
                let instruction = videoFadeTransitionInstruction(at: cursorTime,
                                                                 fromTrack: currentVideoCompositionTrack,
                                                                 toTrack: nextVideoCompositionTrack,
                                                                 fromVideoTrack: fromAssetVideoTrack,
                                                                 toVideoTrack: toAssetVideoTrack)
                compositionInstructions.append(instruction)
            }
        }
        return compositionInstructions
    }
    
    private func videoInstructionTimeRange(start: CMTime, duration: CMTime, isFirstTrack: Bool, isLastTrack: Bool, isPrevTrackTransition: Bool) -> CMTimeRange {
        var timeRange = CMTimeRangeMake(start: start, duration: duration)
        if duration > Constants.fadeTransitionDuration {
            if !isFirstTrack && isPrevTrackTransition {
                timeRange.start = CMTimeAdd(timeRange.start, Constants.fadeTransitionDuration)
                timeRange.duration = CMTimeSubtract(timeRange.duration, Constants.fadeTransitionDuration)
            }
            if !isLastTrack {
                timeRange.duration = CMTimeSubtract(timeRange.duration, Constants.fadeTransitionDuration)
            }
        }
        if isLastTrack, let pipVideoCompositionTrack = pipVideoCompositionTrack {
            let endTime = CMTimeAdd(start, duration)
            let pipEndTime = CMTimeAdd(pipVideoCompositionTrack.timeRange.start, pipVideoCompositionTrack.timeRange.duration)
            if endTime < pipEndTime {
                timeRange.duration = CMTimeAdd(timeRange.duration, CMTimeSubtract(pipEndTime, endTime))
            }
        }
        return timeRange
    }
    
    private func videoFadeTransitionInstruction(at time: CMTime,
                                                fromTrack: AVCompositionTrack,
                                                toTrack: AVCompositionTrack,
                                                fromVideoTrack: AVAssetTrack?,
                                                toVideoTrack: AVAssetTrack?) -> AVMutableVideoCompositionInstruction {
        let timeRange = CMTimeRangeMake(start: time, duration: Constants.fadeTransitionDuration)
        
        let fromLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: fromTrack)
        fromLayerInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: timeRange)

        let toLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: toTrack)
        toLayerInstruction.setOpacityRamp(fromStartOpacity: 0.0, toEndOpacity: 1.0, timeRange: timeRange)
        
        if let fromVideoTrack = fromVideoTrack, let toVideoTrack = toVideoTrack {
            fromLayerInstruction.setTransform(aspectFitTransform(size: fromVideoTrack.naturalSize, renderSize: videoRenderSize), at: timeRange.start)
            toLayerInstruction.setTransform(aspectFitTransform(size: toVideoTrack.naturalSize, renderSize: videoRenderSize), at: timeRange.start)
        }
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []
        
        if let pipLayerInstruction = pipLayerInstruction, let pipVideoCompositionTrack = pipVideoCompositionTrack {
            let pipEndTime = CMTimeAdd(pipVideoCompositionTrack.timeRange.start, pipVideoCompositionTrack.timeRange.duration)
            let instructionEndTime = CMTimeAdd(time, Constants.fadeTransitionDuration)
            if pipEndTime >= instructionEndTime {
                layerInstructions.append(pipLayerInstruction)
            }
        }
        layerInstructions.append(fromLayerInstruction)
        layerInstructions.append(toLayerInstruction)
        instruction.layerInstructions = layerInstructions
        
        return instruction
    }
    
    // MARK: - Transform
    
    private func aspectFitTransform(size: CGSize, renderSize: CGSize) -> CGAffineTransform {
        let fitSize = size.aspectFit(size: renderSize)
        let scaleTransform = CGAffineTransform(scaleX: fitSize.width / size.width,
                                               y: fitSize.height / size.height)
        let transaltionTransform = CGAffineTransform(translationX: (renderSize.width - fitSize.width) * 0.5,
                                                     y: (renderSize.height - fitSize.height) * 0.5)
        return scaleTransform.concatenating(transaltionTransform)
    }
    
    private func pipTransform(size: CGSize, renderSize: CGSize) -> CGAffineTransform {
        let fitSize = size.aspectFit(size: renderSize)
        let updatedFitSize = CGSize(width: fitSize.width * 0.5, height: fitSize.height * 0.5)
        let scaleTransform = CGAffineTransform(scaleX: updatedFitSize.width / size.width,
                                               y: updatedFitSize.height / size.height)
        let transaltionTransform = CGAffineTransform(translationX: 0,
                                                     y: renderSize.height - updatedFitSize.height)
        return scaleTransform.concatenating(transaltionTransform)
    }
}
