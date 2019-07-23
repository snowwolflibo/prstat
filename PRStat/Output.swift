//
//  Output.swift
//  PRStat
//
//  Created by bo li on 2019/7/23.
//  Copyright © 2019 zilly. All rights reserved.
//

import UIKit

class Output: NSObject {
    
    static private func textWithTab(text: String, length: Int, isLast: Bool) -> String {
        let spaceNumber = max(0, length - 1 - text.count)
        return " " + text + String(repeating: " ", count: spaceNumber) + (isLast ? "" : "|")
    }

    static func textWithTab(array: [String], titleAndLengths: [(String,Int)]) -> String {
        var result = ""
        array.enumerated().forEach { (index, text) in result += textWithTab(text: text, length: titleAndLengths[index].1, isLast: index == array.count - 1) }
        return result
    }

    static func outputTitles(array: [(String,Int)]) -> String {
        let result = array.reduce("") { $0 + textWithTab(text: $1.0, length: $1.1, isLast: false) }
        return result.subString(start: 0, length: result.count - 1)
    }
}
