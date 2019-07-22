//
//  ApiRequestParameter.swift
//  Whisky
//
//  Created by bo li on 2018/5/21.
//  Copyright © 2018年 bo li. All rights reserved.
//

import UIKit
import PromiseKit
import CryptoSwift

class ApiRequestParameter: NSObject {

    private var url: String
    var body: Parameters?
    var querys: Parameters!
    var headers: HTTPHeaders

    var timestamp: Int!
    var device_id: String!
    var device_type: Int!
    var app_version: String!
    var user_name: String?
    var nonce: String!

    init(url: String = "", body: Parameters?, querys: Parameters?) {
        self.url = url
        self.body = body
        self.querys = querys

        self.headers = [
            "Authorization" : "token 9d3fd25027a72e29d2d559b4ad72c890078610a5",
            "Accept" : "application/vnd.github.shadow-cat-preview+json,application/vnd.github.sailor-v-preview+json,application/vnd.github.squirrel-girl-preview"
        ]
    }


    func getQueryString() -> String {

        var queryString = ""
        if let _querys = querys {
            for (offset: index, element: (key: key, value: value)) in _querys.enumerated() {
                let strValue = value as! String
                queryString += "\(key)=\(strValue)"
                if index < _querys.count - 1 {
                    queryString += "&"
                }
            }
        }
        return queryString
    }

    func getURL() -> String {
        let queryString = getQueryString()
        return queryString.isEmpty ? url : url + "?" + queryString
    }
}
