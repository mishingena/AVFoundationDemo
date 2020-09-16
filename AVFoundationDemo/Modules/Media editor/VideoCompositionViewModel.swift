//
//  VideoCompositionViewModel.swift
//  AVFoundationDemo
//
//  Created by Gennadiy Mishin on 15.09.2020.
//  Copyright © 2020 GM. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class VideoCompositionViewModel {
    
    private enum Constants {
        static let defaultVideoFileExtension = "mp4"
        static let outputFilePrefix = "output-video-"
        static let unknownError = NSError(domain: "AVErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: "UnknownError"])
    }
    
    var mediaURLs: [URL] = []
    
    func exportPiPVideo(completion: ((Swift.Result<URL, Error>) -> Void)?) {
        guard mediaURLs.count == 2, let mainURL = mediaURLs.first, let pictureURL = mediaURLs.last else { return }
        
        let composer = PiPVideoComposer()
        composer.composeMediaItems(mainVideoURL: mainURL, pictureVideoURL: pictureURL, keepAudio: true)
        
        export(composition: composer.composition, videoComposition: composer.videoComposition) { (url) in
            if let url = url {
                completion?(.success(url))
            } else {
                completion?(.failure(Constants.unknownError))
            }
        }
    }
    
    func exportVideo(completion: ((Swift.Result<URL, Error>) -> Void)?) {
        let composer = VideoComposer()
        composer.composeMediaItemsWithFadeTransition(urls: mediaURLs, keepAudio: true)
        if let error = composer.error {
            completion?(.failure(error))
            return
        }
        
        export(composition: composer.composition, videoComposition: composer.videoComposition) { (url) in
            if let url = url {
                completion?(.success(url))
            } else {
                completion?(.failure(Constants.unknownError))
            }
        }
    }
    
    func saveMediaToCameraRoll(url: URL, completion: ((Error?) -> Void)?) {
        PHPhotoLibrary.shared().performChanges ({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }, completionHandler: { saved, error in
            DispatchQueue.main.async {
                if saved {
                    completion?(nil)
                } else {
                    completion?(error ?? Constants.unknownError)
                }
            }
        })
    }
    
    func requestAccessToPhotosIfNeeded(completion: ((Bool) -> Void)?) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            completion?(true)
        case .denied, .restricted:
            completion?(false)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (newStatus) in
                DispatchQueue.main.async {
                    completion?(newStatus == .authorized)
                }
            })
        @unknown default:
            completion?(false)
        }
    }
    
    // MARK: - Private
    
    private func export(composition: AVComposition, videoComposition: AVVideoComposition, completion: ((URL?) -> Void)?) {
        guard let exporter = AVAssetExportSession(asset: composition,
                                                  presetName: AVAssetExportPresetHighestQuality) else {
                                                    completion?(nil)
                                                    return
        }
        
        exporter.outputURL = generateOutputFileURL(ext: Constants.defaultVideoFileExtension)
        exporter.videoComposition = videoComposition
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true

        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                completion?(exporter.outputURL)
            }
        }
    }
    
    private func generateOutputFileURL(ext: String) -> URL? {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let filename = "\(Constants.outputFilePrefix)\(Date.timeIntervalSinceReferenceDate)"
        return documentDirectory.appendingPathComponent(filename).appendingPathExtension(ext)
    }
}
