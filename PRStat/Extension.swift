//
//  Extension.swift
//  PRStat
//
//  Created by bo li on 2019/7/23.
//  Copyright © 2019 zilly. All rights reserved.
//

import UIKit

func formatted(_ value: Float) -> Float {
    return Float(String(format: "%.2f", value))!
}

extension Int {
    var commaString: String {
//        return "\(self)".commaString
        return NSNumber(value: self).commaString
    }
}

extension Float {
    var commaString: String {
//        return "\(self)".commaString
        return NSNumber(value: self).commaString
    }
}

extension NSNumber {
    var commaString: String {
        let format = NumberFormatter()
        format.numberStyle = .decimal
        return format.string(from: self)!
    }
}
