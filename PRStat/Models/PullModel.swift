//
//  PullModel.swift
//  PRStat
//
//  Created by bo li on 2019/7/21.
//  Copyright © 2019 zilly. All rights reserved.
//

import HandyJSON

struct PullSummaryModel: HandyJSON {
    var number: Int = 0
    var created_at: String = ""
    var merged_at: String?
    var url: String = ""
    var commits_url: String = ""
    var comments_url: String = ""
    var review_comments_url: String = ""
    func commentsUrl(type: CommentType) -> String {
        return type == .comment ? comments_url : review_comments_url
    }
}

class PullModel: HandyJSON {
    var number: Int = 0
    var url: String = ""
    var html_url: String = ""
    private var user: UserModel?
    private var assignees: [UserModel]?
    var true_user: UserModel? {
        guard assignees?.count == 1 else { return user }
        return assignees![0]
    }
    var state: PullState = .open
    var title: String = ""
    var created_at: String = ""
    var merged_at: String?
    var duration: Int {
        let createdDate = created_at.toDate
        let mergedDate = merged_at?.toDate ?? Date()
        let days = mergedDate.timeIntervalSince(createdDate) / (3600 * 24)
        return Int(days)
    }
    var durationString: String { return "\(duration) days" }
    var merged: Bool = false
    var commits: Int = 0
    var additions: Int = 0
    var deletions: Int = 0
    var changed_lines: Int { return additions + deletions }
    var changed_files: Int = 0
    var comments: Int = 0
    var reviews: Int = 0
    var review_comments: Int = 0

    required init() { }

    var outputValues: String {
        let array = [
            "\(number)",
            "\(true_user?.login ?? "")",
            "\(state)",
            "\(created_at)",
            "\(merged)",
            "\(durationString)",
            "\(commits.commaString)",
            "\(comments.commaString)",
            "\(review_comments.commaString)",
            "\(reviews.commaString)",
            "\(additions.commaString)",
            "\(deletions.commaString)",
            "\(changed_lines.commaString)",
            "\(changed_files.commaString)",
            "\(title)",
        ]
        return Output.textWithTab(array: array, titleAndLengths: PullModel.titleAndLengths)
    }

    static var titleAndLengths = [
        ("number",10),
        ("dev",20),
        ("state",10),
        ("created_at",25),
        ("merged",10),
        ("duration",10),
        ("commits",10),
        ("comments",10),
        ("rev_comments",15),
        ("reviews",15),
        ("lines_add",15),
        ("lines_del",15),
        ("lines",10),
        ("files",10),
        ("title",60),
    ]

    static var outputTitles: String {
        return Output.outputTitles(array: titleAndLengths)
    }
}

