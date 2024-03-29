//
//  UserLineAndCommentModel.swift
//  PRStat
//
//  Created by bo li on 2019/7/22.
//  Copyright © 2019 zilly. All rights reserved.
//

struct UserLineAndCommentModel {
    let user: String
    var additions: Int = 0
    var deletions: Int = 0
    var lines: Int { return additions + deletions }
    var review_comments_per_lines: Float { return lines == 0 ? 0 : Float(comment_count * 1000) / Float(lines) }
    var comments_to_others: [CommentType:Int] = [
        .comment: 0,
        .reviewComment: 0
    ]
    var commits: [CommitModel] = []
    var comment_count: Int { return commits.reduce(0) { $0 + $1.review_comments } }

    init(user: String) {
        self.user = user
    }

    var outputValues: String {
        let array = [
            "\(user)",
            "\(comments_to_others[.comment]!.commaString)",
            "\(comments_to_others[.reviewComment]!.commaString)",
            "\(commits.count.commaString)",
            "\(additions.commaString)",
            "\(deletions.commaString)",
            "\(lines.commaString)",
            "\(comment_count.commaString)",
            review_comments_per_lines.commaString
        ]
        return Output.textWithTab(array: array, titleAndLengths: UserLineAndCommentModel.titleAndLengths)
    }

    static var titleAndLengths = [
        ("dev",25),
        ("comments_given",20),
        ("rev_comments_given",20),
        ("commits",10),
        ("lines_add",15),
        ("lines_del",15),
        ("lines",15),
        ("rev_comments",20),
        ("rev_comments/1000 lines",25),
    ]

    static var outputTitles: String {
        return Output.outputTitles(array: titleAndLengths)
    }
}
