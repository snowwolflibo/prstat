//
//  CommitModel.swift
//  PRStat
//
//  Created by bo li on 2019/7/23.
//  Copyright © 2019 zilly. All rights reserved.
//

import HandyJSON

class CommitModel: HandyJSON {
    struct Commit: HandyJSON {
        var message: String!
        var comment_count: Int = 0
        var committer: Committer!
    }

    struct Committer: HandyJSON {
        var date: String = ""
    }

    struct Stats: HandyJSON {
        var additions: Int = 0
        var deletions: Int = 0
        var displayText: String { return "additions:\(additions);deletions:\(deletions)" }
    }

    var author: UserModel!
    var sha: String!
    var url: String!
    var comments_url: String!
    var commit: Commit!
    var stats: Stats!
    required init() { }
}
