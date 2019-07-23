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

struct PullModel: HandyJSON {
    var number: Int = 0
    var url: String = ""
    private var user: UserModel?
    private var assignees: [UserModel]?
    var true_user: UserModel? {
        guard assignees?.count == 1 else { return user }
        return assignees![0]
//        var assignee = assignees![0]
//        if let login = Config.aliasAndLoginNameDictionary[assignee.login] {
//            assignee.login = login
//        }
//        return assignee
    }
    var state: PullState = .open
    var title: String = ""
    var created_at: String = ""
    var merged_at: String?
    var duration: Int {
        let createdDate = date(from: created_at)
        let mergedDate = merged_at == nil ? Date() : date(from: merged_at!)
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
    var review_comments: Int = 0
    var titleOutput: String { return "title:\(title)(\(url))\tuser:\(user?.login ?? "")" }

    var detailOutput: String {
        return "state:\(state)\t" +
        "created_at:\(created_at)\t" +
        "merged:\(merged)\t" +
        "duration:\(durationString)\t" +
        "commits:\(commits)\t" +
        "comments:\(comments)\t" +
        "review_comments:\(review_comments)\t" +
        "additions:\(additions)\t" +
        "deletions:\(deletions)\t" +
        "changed_lines:\(changed_lines)\t" +
        "changed_files:\(changed_files)\t"
    }

    private func date(from string: String) -> Date {
        var dateString = string.replacingOccurrences(of: "T", with: " ")
        dateString = dateString.replacingOccurrences(of: "Z", with: "")
        let formatter = DateFormatter()
        formatter.locale = Locale.init(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = formatter.date(from: dateString)
        return date!
    }
}

func textWithTab(text: String, length: Int) -> String {
    let spaceNumber = max(0, length - 1 - text.count)
    return " " + text + String(repeating: " ", count: spaceNumber) + "|"
}
