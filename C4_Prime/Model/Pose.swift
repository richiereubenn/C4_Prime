//
//  Pose.swift
//  C4_Prime
//
//  Created by Richie Reuben Hermanto on 22/06/25.
//

import Foundation

struct Pose: Identifiable {
    let id = UUID()
    let title: String
    let imageName: String
    let available: Bool
}

struct PoseModel {
    static let poses: [Pose] = [
        Pose(title: "Front Double\nBicep", imageName: "front-double-bicep", available: true),
        Pose(title: "Back Double\nBicep", imageName: "front-double-bicep", available: false),
        Pose(title: "Side Chest", imageName: "front-double-bicep", available: false)
    ]
}
