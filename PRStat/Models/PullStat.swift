//
//  PullStat.swift
//  PRStat
//
//  Created by bo li on 2019/7/22.
//  Copyright © 2019 zilly. All rights reserved.
//

import Foundation

class Stat {
    var pullStats: [PullStat]!
    var allCommits: [String:CommitModel] = [:]
}

class PullStat {
    var dateRange: DateRange
    var userPulls: [PullStatType:[String:UserPullModel]] = [
        .created: [:],
        .merged: [:]
    ]
    var userLineAndComments: [String:UserLineAndCommentModel]
    var createdPulls: [PullModel]

    init(dateRange: DateRange, userLineAndComments: [String:UserLineAndCommentModel], createdPulls: [PullModel]) {
        self.dateRange = dateRange
        self.userLineAndComments = userLineAndComments
        self.createdPulls = createdPulls
    }

    private var output: String {
        var result = ""
        // Date
        result = addLine(original: result, newLine: "Stat Month: \(dateRange.displayText)")
        // User Pulls
        let userPullBlock = { (pullStatType: PullStatType) in
            let userPullsOfThisType = self.userPulls[pullStatType]!
            let sortedUserPulls = userPullsOfThisType.values.sorted { userPull1, userPull2 -> Bool in
                return userPull1.user.compare(userPull2.user) == .orderedAscending
            }
            result = self.addLine(original: result, newLine: "\r\n============= user pulls - \(pullStatType.rawValue) (\(sortedUserPulls.reduce(0) { $0 + $1.pulls.count })) ==============\r\n")
            result = self.addLine(original: result, newLine: UserPullModel.outputTitles)
            sortedUserPulls.forEach {
                result = self.addLine(original: result, newLine: $0.outputValues)
            }
        }
        userPullBlock(.created)
        userPullBlock(.merged)
        // User Lines and Comments
        let sortedUserLinesAndComments = userLineAndComments.values.sorted { model1, model2 -> Bool in
            return model1.user.compare(model2.user) == .orderedAscending
        }
        result = addLine(original: result, newLine: "\r\n============= user lines and comments (\(userLineAndComments.count)) ==============\r\n")
        result = addLine(original: result, newLine: UserLineAndCommentModel.outputTitles)
        sortedUserLinesAndComments.forEach {
            result = addLine(original: result, newLine: $0.outputValues)
        }
        // Pulls
        let sortedPulls = createdPulls.sorted { pull1, pull2 -> Bool in
            let compareResult = pull1.user!.login.compare(pull2.user!.login)
            if compareResult == .orderedSame {
                return pull1.number > pull2.number
            } else {
                return compareResult == .orderedAscending
            }
        }
        result = addLine(original: result, newLine: "\r\n============= new pulls (\(sortedPulls.count))==============\r\n")
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