//
//  PhotoModels.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/3/22.
//

import Foundation
import UIKit

struct PhotoCapturePayload {
    let embedding: [Float]
    let image: UIImage
    let sessionID: Int64
}
