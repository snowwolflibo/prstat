//
//  LogUtility.swift
//  PRStat
//
//  Created by bo li on 2019/7/21.
//  Copyright © 2019 zilly. All rights reserved.
//

class LogUtility {

    static func log(_ text: String) {
        if Config.logForApi {
            print(text)
        }
    }
}
