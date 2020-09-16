//
//  MediaItemCell.swift
//  AVFoundationDemo
//
//  Created by Gennadiy Mishin on 15.09.2020.
//  Copyright © 2020 GM. All rights reserved.
//

import UIKit
import AVFoundation

class MediaItemCell: UITableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        imageView?.contentMode = .scaleAspectFit
        textLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
        textLabel?.numberOfLines = 2
    }
    
    func updateUI(assetURL: URL) {
        textLabel?.text = assetURL.absoluteURL.lastPathComponent
        imageView?.image = AVAsset.generatePreviewImage(assetURL: assetURL)
    }
}
