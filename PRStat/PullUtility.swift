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
        generatePullStats(dateRanges: dateRanges)
    }

    private static func generatePullStats(dateRanges: [DateRange]) {
        fetchAllPulls(dateRanges: dateRanges).done { dateRangePulls in
            var pullStat = PullStat(dateRange: dateRangePulls.dateRange, userPulls: [:], pulls: dateRangePulls.pulls)
            dateRangePulls.pulls.forEach({ pull in
                guard let userName = pull.user?.login else { return }
                var userPull = pullStat.userPulls[userName]
                if userPull == nil {
                    userPull = UserPullModel()
                    pullStat.userPulls[userName] = userPull
                }
                userPull!.pulls.append(pull)
            })
            pullStat.writeToFile()
        }
    }

    private static func fetchAllPulls(dateRanges: [DateRange]) -> Promise<DateRangePullsModel> {
        return Promise<DateRangePullsModel> { seal in
            ApiRequest<[Any]>.getResponsePromise(url: "https://api.github.com/repos/zillyinc/tellus-ios/pulls?state=all&sort=created&direction=desc").done { array in
                let models = [PullModel].deserialize(from: array)!.compactMap { $0 }
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
                        seal.fulfill(DateRangePullsModel(dateRange: dateRange, pulls: detailModels))
                    }).catch({ error in
                        print(error)
                        seal.reject(error)
                    })
                }
            }
        }
    }
}

