//
//  PullModel.swift
//  PRStat
//
//  Created by bo li on 2019/7/21.
//  Copyright © 2019 zilly. All rights reserved.
//

import HandyJSON

enum PullState: String, HandyJSONEnum {
    case open
    case closed
}

struct UserModel: HandyJSON {
    var login: String = ""
}

struct PullModel: HandyJSON {
    var number: Int = 0 // filled in all pulls
    var user: UserModel? // filled in all pulls
    var state: PullState = .open // filled in all pulls
    var title: String = "" // filled in all pulls
    var created_at: String = "" // filled in all pulls
    var updated_at: String = "" // filled in all pulls
    var merged_at: String?
    var duration: Int {
        let createdDate = date(from: created_at)
        let mergedDate = merged_at == nil ? Date() : date(from: merged_at!)
        let days = mergedDate.timeIntervalSince(createdDate) / (3600 * 24)
        return Int(days)
    }
    var durationString: String {
        return "\(duration) days"
    }
    var url: String = ""
    var commits_url: String = "" // filled in all pulls
    var review_comments_url: String = "" // filled in all pulls
    var comments_url: String = "" // filled in all pulls
    var merged: Bool = false // filled in one pull
    var comments: Int = 0 // filled in one pull
    var review_comments: Int = 0 // filled in one pull
    var commits: Int = 0 // filled in one pull
    var additions: Int = 0 // filled in one pull
    var deletions: Int = 0 // filled in one pull
    var changed_lines: Int {
        return additions + deletions
    }
    var changed_files: Int = 0 // filled in one pull

    var titleOutput: String {
        return "title:\(title)(\(url))\tuser:\(user?.login ?? "")"
    }

    var detailOutput: String {

        return "state:\(state)\t" +
        "created_at:\(created_at)\t\t" +
        "merged:\(merged)\t" +
        "duration:\(durationString)\t" +
        "commits:\(commits)\t" +
        "comments:\(comments)\t" +
        "review_comments:\(review_comments)\t\t" +
        "additions:\(additions)\t\t\t" +
        "deletions:\(deletions)\t\t" +
        "changed_lines:\(changed_lines)\t\t" +
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

//    func fill(byDetail detail: PullModel) {
//        merged = detail.merged
//        comments = detail.comments
//        review_comments = detail.review_comments
//        commits = detail.commits
//        additions = detail.additions
//        deletions = detail.deletions
//        changed_files = detail.changed_files
//    }
}

struct DateRange {
    var year: Int = 1970
    var month: Int = 1
    var displayText: String {
        let monthWithPaddingZero = month < 10 ? "0\(month)" : "\(month)"
        return "\(year)-\(monthWithPaddingZero)"
    }
}

struct PullStat {
    var dateRange: DateRange
    var userPulls: [String:UserPullModel]
    var pulls: [PullModel]

    private var output: String {
        var result = ""
        result = addLine(original: result, newLine: "Stat Month: \(dateRange.displayText)")
        let sortedUserPulls = userPulls.values.sorted { userPull1, userPull2 -> Bool in
            return userPull1.user.compare(userPull2.user) == .orderedAscending
        }
        result = addLine(original: result, newLine: "\r\n=============User Pulls Stat (\(userPulls.count))==============\r\n")
        sortedUserPulls.forEach {
            result = addLine(original: result, newLine: $0.output)
            result = addLine(original: result, newLine: "")
        }
        let sortedPulls = pulls.sorted { pull1, pull2 -> Bool in
            let compareResult = pull1.user!.login.compare(pull2.user!.login)
            if compareResult == .orderedSame {
                return pull1.number > pull2.number
            } else {
                return compareResult == .orderedAscending
            }
        }
        result = addLine(original: result, newLine: "\r\n=============Pulls Stat (\(sortedPulls.count))==============\r\n")
        sortedPulls.forEach {
            result = addLine(original: result, newLine: $0.titleOutput)
            result = addLine(original: result, newLine: $0.detailOutput)
            result = addLine(original: result, newLine: "")
        }
        return result
    }

    private func addLine(original: String, newLine: String) -> String {
        return original + newLine + "\r\n"
    }

    func writeToFile() {
        //输出结果出文本文件
        let outputPath = FileUtility.documentFilePath(for: "pullStat-\(dateRange.displayText).txt")
        if FileManager.default.fileExists(atPath: outputPath) {
            try? FileManager.default.removeItem(atPath: outputPath)
        }
        print("Please open \(outputPath) to see the pulls stat")
        let outputURL = URL(fileURLWithPath: outputPath)
        FileManager.default.createFile(atPath: outputPath, contents: nil, attributes: nil)
        let output = self.output
        try? output.write(to: outputURL, atomically: true, encoding: String.Encoding.utf8)
    }
}

struct UserPullModel {
    var user: String = ""
    var pulls: [PullModel] = []

    var created_pulls: Int {
        return pulls.count
    }
    var commits: Int {
        return pulls.reduce(0) { $0 + $1.commits }
    }
    var comments: Int {
        return pulls.reduce(0) { $0 + $1.comments }
    }
    var review_comments: Int {
        return pulls.reduce(0) { $0 + $1.review_comments }
    }
    var average_duration_per_pull: Int {
        return created_pulls == 0 ? 0 : pulls.reduce(0) { $0 + $1.duration } / created_pulls
    }
    var average_duration_per_pull_string: String {
        return "\(average_duration_per_pull) days"
    }
    var average_commits_per_pull: Int {
        return created_pulls == 0 ? 0 : commits / created_pulls
    }
    var average_comments_per_pull: Int {
        return created_pulls == 0 ? 0 : comments / created_pulls
    }
    var average_review_comments_per_pull: Int {
        return created_pulls == 0 ? 0 : review_comments / created_pulls
    }
    var additions: Int {
        return pulls.reduce(0) { $0 + $1.additions }
    }
    var deletions: Int {
        return pulls.reduce(0) { $0 + $1.deletions }
    }
    var changed_lines: Int {
        return additions + deletions
    }
    var average_lines_per_pull: Int {
        return created_pulls == 0 ? 0 : changed_lines / created_pulls
    }
    var open_pulls: Int {
        return pulls.filter { $0.state == .open }.count
    }
    var closed_pulls: Int {
        return pulls.filter { $0.state == .closed }.count
    }
    var average_reviewers_per_pull: Int = 0
    var comments_per_lines: Int {
        return changed_lines == 0 ? 0 : comments * 1000 / changed_lines
    }
    var review_comments_per_lines: Int {
        return changed_lines == 0 ? 0 : review_comments * 1000 / changed_lines
    }

    var output: String {
        return "user:\(user)\r\n" +
        "created_pulls:\(created_pulls)\t\t" +
        "open_pulls:\(open_pulls)\t" +
        "closed_pulls:\(closed_pulls)\t" +
        "commits:\(commits)\t" +
        "comments:\(comments)\t" +
        "review_comments:\(review_comments)\t" +
        "average_duration_per_pull:\(average_duration_per_pull_string)\t" +
        "average_commits_per_pull:\(average_commits_per_pull)\t\t" +
        "average_comments_per_pull:\(average_comments_per_pull)\t\t" +
        "average_review_comments_per_pull:\(average_review_comments_per_pull)\t\t" +
        "changed_lines:\(changed_lines)\t\t" +
        "comments_per_lines:\(comments_per_lines)/1000 lines\t\t" +
        "review_comments_per_lines:\(review_comments_per_lines)/1000 lines\t\t" +
        "average_reviewers_per_pull:\(average_reviewers_per_pull)\t"
    }

}
