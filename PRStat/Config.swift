//
//  Config.swift
//  PRStat
//
//  Created by bo li on 2019/7/23.
//  Copyright © 2019 zilly. All rights reserved.
//

class Config {
    static let alwaysUseCache = true
    static let pageSize: Int = 30
    static func pullsUrl(repository: Repository, page: Int) -> String {
        return "https://api.github.com/repos/zillyinc/\(repository.rawValue)/pulls?state=all&sort=created&direction=desc&page=\(page)"
    }
    static func reviewsUrl(repository: Repository, pullNumber: String, page: Int) -> String {
        return "https://api.github.com/repos/zillyinc/\(repository.rawValue)/pulls/\(pullNumber)/reviews&page=\(page)"
    }
}
