//
//  Entry.swift
//  PhotoJournal
//
//  Created by Mark Kim on 7/11/20.
//  Copyright © 2020 HazeStudio. All rights reserved.
//

import Foundation

struct Entry: Codable {
    let imagePath: String
    let textEntry: String
    let timeStamp: String
}
