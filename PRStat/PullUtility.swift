//
//  PRApi.swift
//  PRStat
//
//  Created by bo li on 2019/7/20.
//  Copyright © 2019 zilly. All rights reserved.
//

import UIKit
import PromiseKit

class PullUtility {

    struct DateRangePullsModel {
        var dateRange: DateRange
        var pulls: [PullModel]
    }

    class AllPagedPullsModel {
        var pulls: [PullModel] = []
    }

    typealias PullsAction = ([PullModel]) -> Void

    static func generatePullStats() {
        let today = Date()
        let calendar = Calendar(identifier: .gregorian)
        var dateRanges: [DateRange] = []
        for i in 0..<5 {
            var monthAdded = DateComponents()
            monthAdded.month = -i
            let newDate = calendar.date(byAdding: monthAdded, to: today)!
            dateRanges.append(DateRange(year: calendar.component(.year, from: newDate), month: calendar.component(.month, from: newDate)))
        }
        fetchAllPulls(dateRanges: dateRanges)
    }

    private static func handleDateRangePulls(dateRangePulls: DateRangePullsModel) {
        var pullStat = PullStat(dateRange: dateRangePulls.dateRange, userPulls: [:], pulls: dateRangePulls.pulls)
        dateRangePulls.pulls.forEach({ pull in
            guard let user = pull.user?.login else { return }
            if pullStat.userPulls[user] == nil {
                var userPull = UserPullModel()
                userPull.user = user
                pullStat.userPulls[user] = userPull
            }
            pullStat.userPulls[user]?.pulls.append(pull)
        })
        pullStat.writeToFile()
    }

    private static func handleAllPagedPulls(dateRanges: [DateRange], models: [PullModel]) {
        dateRanges.forEach { dateRange in
            let modelsInThisDateRange = models.filter {
                $0.created_at.contains(dateRange.displayText)
            }
            var fetchMultiplePullsPromise: [Promise<[String:Any]>] = []
            modelsInThisDateRange.forEach({ model in
                let promise = ApiRequest<[String:Any]>.getResponsePromise(url: model.url)
                fetchMultiplePullsPromise.append(promise)
            })
            when(fulfilled: fetchMultiplePullsPromise).done({ array in
                let detailModels = [PullModel].deserialize(from: array)!.compactMap { $0 }
                handleDateRangePulls(dateRangePulls: DateRangePullsModel(dateRange: dateRange, pulls: detailModels))
            }).catch({ error in
                print(error)
            })
        }
    }
    private static func fetchAllPulls(dateRanges: [DateRange]) {
        fetchAllPagedPulls(firstPage: 1, allPagedPulls: AllPagedPullsModel()) { pulls in
            handleAllPagedPulls(dateRanges: dateRanges, models: pulls)
        }
    }

    private static func fetchAllPagedPulls(firstPage: Int = 1, allPagedPulls: AllPagedPullsModel, completionHandler: @escaping PullsAction) {
        _ = ApiRequest<[Any]>.getResponsePromise(url: "https://api.github.com/repos/zillyinc/tellus-ios/pulls?state=all&sort=created&direction=desc&page=\(firstPage)").done { array in
            let models = [PullModel].deserialize(from: array)!.compactMap { $0 }
            allPagedPulls.pulls += models
            if models.isEmpty {
                completionHandler(allPagedPulls.pulls)
            } else {
                fetchAllPagedPulls(firstPage: firstPage + 1, allPagedPulls: allPagedPulls, completionHandler: completionHandler)
            }
        }
    }
}

