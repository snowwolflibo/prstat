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
    var reviews: Int { return pulls.reduce(0) { $0 + $1.reviews } }
    var average_duration_per_pull: Float { return created_pulls == 0 ? 0 : Float(pulls.reduce(0) { $0 + $1.duration }) / Float(created_pulls) }
    var average_duration_per_pull_string: String { return "\(average_duration_per_pull.standardRounded) days" }
    var average_commits_per_pull: Float { return created_pulls == 0 ? 0 : Float(commits) / Float(created_pulls) }
    var average_comments_per_pull: Float { return created_pulls == 0 ? 0 : Float(comments) / Float(created_pulls) }
    var average_review_comments_per_pull: Float { return created_pulls == 0 ? 0 : Float(review_comments) / Float(created_pulls) }
    var average_reviews_per_pull: Float { return created_pulls == 0 ? 0 : Float(reviews) / Float(created_pulls) }
    var additions: Int { return pulls.reduce(0) { $0 + $1.additions } }
    var deletions: Int { return pulls.reduce(0) { $0 + $1.deletions } }
    var changed_lines: Int { return additions + deletions }
    var average_lines_per_pull: Float { return created_pulls == 0 ? 0 : Float(changed_lines) / Float(created_pulls) }
    var open_pulls: Int { return pulls.filter { $0.state == .open }.count }
    var closed_pulls: Int { return pulls.filter { $0.state == .closed }.count }
    var comments_per_lines: Float { return changed_lines == 0 ? 0 : Float(comments * 1000) / Float(changed_lines) }
    var review_comments_per_lines: Float { return changed_lines == 0 ? 0 : Float(review_comments * 1000) / Float(changed_lines) }

    init(user: String) {
        self.user = user
    }

    func outputValues(pullStatType: PullStatType) -> String {
        let array = [
            "\(user)",
            "\(created_pulls)",
            pullStatType == .created ? "\(open_pulls)" : "-",
            "\(closed_pulls)",
            "\(commits.commaString)",
            "\(comments.commaString)",
            "\(review_comments.commaString)",
            "\(reviews.commaString)",
            "\(average_duration_per_pull_string)",
            average_commits_per_pull.commaString,
            average_comments_per_pull.commaString,
            average_review_comments_per_pull.commaString,
            average_reviews_per_pull.commaString,
            "\(changed_lines.commaString)",
            "\(additions.commaString)",
            "\(deletions.commaString)",
            comments_per_lines.commaString,
            review_comments_per_lines.commaString,
        ]
        return Output.textWithTab(array: array, titleAndLengths: UserPullModel.titleAndLengths)
    }

    static var titleAndLengths = [
        ("dev(as unique assignee or creater)",35),
        ("prs",10),
        ("prs_open",10),
        ("prs_closed",15),
        ("commits",10),
        ("pr_comments",15),
        ("pr_rev_comments",20),
        ("pr_reviews",20),
        ("avg_pr_duration",20),
        ("avg_pr_commits",20),
        ("avg_pr_comments",20),
        ("avg_pr_rev_comments",25),
        ("avg_pr_reviews",20),
        ("lines",10),
        ("lines_add",15),
        ("lines_del",15),
        ("comments/1000 lines",25),
        ("rev_comments/1000 lines",25),
    ]

    static var outputTitles: String {
        return Output.outputTitles(array: titleAndLengths)
    }
}
