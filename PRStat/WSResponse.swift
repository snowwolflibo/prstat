//
//  WSResponse.swift
//  Whisky
//
//  Created by bo li on 2018/3/19.
//  Copyright © 2018年 bo li. All rights reserved.
//

import UIKit
import HandyJSON

class SimpleResponse: HandyJSON {
    var code: Int = -1
    var message: String?

    required init() {

    }
}

class WSResponse<T>: SimpleResponse {
    var data: T?

    required init() {

    }
    convenience init(data: T, code: Int, message: String?) {
        self.init()
        self.data = data
        self.code = code
        self.message = message
    }
}
