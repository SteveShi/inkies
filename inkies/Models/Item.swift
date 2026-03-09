//
//  Item.swift
//  inkies
//
//  Created by 石屿 on 2026/1/12.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var title: String
    var content: String
    
    init(timestamp: Date, title: String = "Untitled", content: String = "") {
        self.timestamp = timestamp
        self.title = title
        self.content = content
    }
}
