//
//  CommentModel.swift
//  PRStat
//
//  Created by bo li on 2019/7/23.
//  Copyright © 2019 zilly. All rights reserved.
//

import HandyJSON

struct CommentModel: HandyJSON {
    var user: UserModel!
    var created_at: String = ""
    var commit_id: String!
}
