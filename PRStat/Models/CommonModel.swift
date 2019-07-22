//
//  CommonModel.swift
//  PRStat
//
//  Created by bo li on 2019/7/22.
//  Copyright © 2019 zilly. All rights reserved.
//

import HandyJSON

enum Repository: String {
    case iOS = "tellus-ios"
    case android = "tellus-android"
}

enum PullState: String, HandyJSONEnum {
    case open
    case closed
}

enum PullStatType: String {
    case created
    case merged
}

enum CommentType: String {
    case comment, reviewComment
}

struct DateRange {
    var year: Int = 1970
    var month: Int = 1
    var displayText: String {
        let monthWithPaddingZero = month < 10 ? "0\(month)" : "\(month)"
        return "\(year)-\(monthWithPaddingZero)"
    }
}

struct UserModel: HandyJSON {
    var login: String = ""
}
