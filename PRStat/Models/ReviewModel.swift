//
//  ReviewModel.swift
//  PRStat
//
//  Created by bo li on 2019/7/23.
//  Copyright © 2019 zilly. All rights reserved.
//

import HandyJSON

struct ReviewModel: HandyJSON {
    var commit_id: String!
    var user: UserModel!
}
