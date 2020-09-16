//
//  MediaPickerController.swift
//  AVFoundationDemo
//
//  Created by Gennadiy Mishin on 15.09.2020.
//  Copyright © 2020 GM. All rights reserved.
//

import UIKit
import MobileCoreServices

class MediaPickerController: UIImagePickerController {

    typealias SourceType = UIImagePickerController.SourceType
    
    var completion: ((URL) -> Void)?
    var dismissCompletion: (() -> Void)?
    
    @discardableResult
    func prepareVideoPicker(source: SourceType) -> Bool {
        let movieMediaType = kUTTypeMovie as String
        guard let availableTypes = UIImagePickerController.availableMediaTypes(for: source), availableTypes.contains(movieMediaType) else {
            return false
        }
        
        sourceType = source
        mediaTypes = [movieMediaType]
        allowsEditing = true
        delegate = self
        
        switch source {
        case .camera:
            cameraCaptureMode = .video
        default:
            break
        }
        
        return true
    }
    
    static func availableSources() -> [SourceType] {
        let allSources: [UIImagePickerController.SourceType] = [.camera, .photoLibrary, .savedPhotosAlbum]
        return allSources.filter({ UIImagePickerController.isSourceTypeAvailable($0) })
    }
}

extension MediaPickerController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard
            picker == self,
            let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String, mediaTypes.contains(mediaType),
            let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL else { return }
        
        completion?(url)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        guard picker == self else { return }
        dismissCompletion?()
    }
}

extension MediaPickerController: UINavigationControllerDelegate {
    // required for UIImagePickerController.delegate
}
