//
//  Extension.swift
//  PRStat
//
//  Created by bo li on 2019/7/23.
//  Copyright © 2019 zilly. All rights reserved.
//

import UIKit

extension Int {
    var commaString: String {
        return NSNumber(value: self).commaString
    }
}

extension Float {
    var commaString: String {
        return NSNumber(value: self.standardRounded).commaString
    }

    var standardRounded: Float {
        return Float(String(format: "%.2f", self))!
    }
}

extension NSNumber {
    var commaString: String {
        let format = NumberFormatter()
        format.numberStyle = .decimal
        return format.string(from: self)!
    }
}
