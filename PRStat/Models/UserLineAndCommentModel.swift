//
//  UserLineAndCommentModel.swift
//  PRStat
//
//  Created by bo li on 2019/7/22.
//  Copyright © 2019 zilly. All rights reserved.
//

struct UserLineAndCommentModel {
    var user: String = ""
    var additions: Int = 0
    var deletions: Int = 0
    var lines: Int { return additions + deletions }
    var comment_count: Int = 0
    var review_comments_per_lines: Int { return lines == 0 ? 0 : comment_count * 1000 / lines }
    var comments_to_others: [CommentType:Int] = [
        .comment: 0,
        .reviewComment: 0
    ]

    var outputValues: String {
        let array = [
            "\(user)",
            "\(comments_to_others[.comment]!)",
            "\(comments_to_others[.reviewComment]!)",
            "\(additions)",
            "\(deletions)",
            "\(lines)",
            "\(comment_count)",
            "\(review_comments_per_lines)"
        ]
        var result = ""
        array.enumerated().forEach { (index, text) in result += textWithTab(text: text, length: UserLineAndCommentModel.titleAndLengths[index].1) }
        return result
    }

    static var titleAndLengths = [
        ("dev",25),
        ("comments_given",20),
        ("rev_comments_given",20),
        ("lines_add",15),
        ("lines_del",15),
        ("lines",15),
        ("rev_comments",20),
        ("rev_comments/1000 lines",25),
    ]

    static var outputTitles: String {
        let array = titleAndLengths
        return array.reduce("") { $0 + textWithTab(text: $1.0, length: $1.1) }
    }
}
