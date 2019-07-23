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
//    var titleOutput: String { return "title:\(title)(\(url))\tuser: \(true_user?.login ?? "") \t\t creater: \(user?.login ?? "")" }

//    var detailOutput: String {
//        return "state:\(state)\t" +
//        "created_at:\(created_at)\t" +
//        "merged:\(merged)\t" +
//        "duration:\(durationString)\t" +
//        "commits:\(commits.commaString)\t" +
//        "comments:\(comments.commaString)\t" +
//        "review_comments:\(review_comments.commaString)\t" +
//        "additions:\(additions.commaString)\t" +
//        "deletions:\(deletions.commaString)\t" +
//        "changed_lines:\(changed_lines.commaString)\t" +
//        "changed_files:\(changed_files.commaString)\t"
//    }
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
            "\(additions.commaString)",
            "\(deletions.commaString)",
            "\(changed_lines.commaString)",
            "\(changed_files.commaString)",
            "\(title)",
        ]
//        var result = ""
//        array.enumerated().forEach { (index, text) in result += textWithTab(text: text, length: PullModel.titleAndLengths[index].1) }
//        return result
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
        ("lines_add",15),
        ("lines_del",15),
        ("lines",10),
        ("files",10),
        ("title",60),
    ]

    static var outputTitles: String {
        return Output.outputTitles(array: titleAndLengths)
//        let array = titleAndLengths
//        return array.reduce("") { $0 + textWithTab(text: $1.0, length: $1.1) }
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

