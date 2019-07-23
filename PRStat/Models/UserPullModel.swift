//
//  UserPullModel.swift
//  PRStat
//
//  Created by bo li on 2019/7/22.
//  Copyright © 2019 zilly. All rights reserved.
//

struct UserPullModel {
    let user: String
    var pulls: [PullModel] = []
    var created_pulls: Int { return pulls.count }
    var commits: Int { return pulls.reduce(0) { $0 + $1.commits } }
    var comments: Int { return pulls.reduce(0) { $0 + $1.comments } }
    var review_comments: Int { return pulls.reduce(0) { $0 + $1.review_comments } }
    var average_duration_per_pull: Int { return created_pulls == 0 ? 0 : pulls.reduce(0) { $0 + $1.duration } / created_pulls }
    var average_duration_per_pull_string: String { return "\(average_duration_per_pull) days" }
    var average_commits_per_pull: Int { return created_pulls == 0 ? 0 : commits / created_pulls }
    var average_comments_per_pull: Int { return created_pulls == 0 ? 0 : comments / created_pulls }
    var average_review_comments_per_pull: Int { return created_pulls == 0 ? 0 : review_comments / created_pulls }
    var additions: Int { return pulls.reduce(0) { $0 + $1.additions } }
    var deletions: Int { return pulls.reduce(0) { $0 + $1.deletions } }
    var changed_lines: Int { return additions + deletions }
    var average_lines_per_pull: Int { return created_pulls == 0 ? 0 : changed_lines / created_pulls }
    var open_pulls: Int { return pulls.filter { $0.state == .open }.count }
    var closed_pulls: Int { return pulls.filter { $0.state == .closed }.count }
    var average_reviews_per_pull: Int = 0
    var comments_per_lines: Int { return changed_lines == 0 ? 0 : comments * 1000 / changed_lines }
    var review_comments_per_lines: Int { return changed_lines == 0 ? 0 : review_comments * 1000 / changed_lines }

    init(user: String) {
        self.user = user
    }

    var outputValues: String {
        let array = [
            "\(user)",
            "\(created_pulls)",
            "\(open_pulls)",
            "\(closed_pulls)",
            "\(commits)",
            "\(comments)",
            "\(review_comments)",
            "\(average_duration_per_pull_string)",
            "\(average_commits_per_pull)",
            "\(average_comments_per_pull)",
            "\(average_review_comments_per_pull)",
            "\(changed_lines)",
            "\(additions)",
            "\(deletions)",
            "\(comments_per_lines)",
            "\(review_comments_per_lines)",
            "\(average_reviews_per_pull)"
        ]
        var result = ""
        array.enumerated().forEach { (index, text) in result += textWithTab(text: text, length: UserPullModel.titleAndLengths[index].1) }
        return result
    }

    static var titleAndLengths = [
        ("dev",25),
        ("prs",10),
        ("prs_open",10),
        ("prs_closed",15),
        ("commits",10),
        ("pr_comments",15),
        ("pr_rev_comments",20),
        ("avg_pr_duration",20),
        ("avg_pr_commits",20),
        ("avg_pr_comments",20),
        ("avg_pr_rev_comments",25),
        ("lines",10),
        ("lines_add",15),
        ("lines_del",15),
        ("comments/1000 lines",25),
        ("rev_comments/1000 lines",25),
        ("avg_pr_reviews",20)
    ]

    static var outputTitles: String {
        let array = titleAndLengths
        return array.reduce("") { $0 + textWithTab(text: $1.0, length: $1.1) }
    }
}
