//
//  CGSizeExtensions.swift
//  AVFoundationDemo
//
//  Created by Gennadiy Mishin on 16.09.2020.
//  Copyright © 2020 GM. All rights reserved.
//

import UIKit

extension CGSize {

    func aspectFit(size: CGSize) -> CGSize {
        guard size != .zero else { return .zero }
        
        let mW = size.width / width
        let mH = size.height / height
        var result = size
        if mH < mW {
            result.width = size.height / height * width
        } else if mW < mH {
            result.height = size.width / width * height
        }
        return result
    }
}
