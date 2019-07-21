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

    // MARK: Relatived struct & typealias

    struct DateRangePullsModel {
        var dateRange: DateRange
        var pulls: [PullModel]
    }

    class AllPagedPullsModel {
        var pulls: [PullModel] = []
    }

    class AllPagedCommentsModel {
        var comments: [CommentModel] = []
    }

    typealias PullsAction = ([PullModel]) -> Void

    typealias CommentsAction = ([CommentModel]) -> Void

    // MARK: Variable

    private static let pageSize: Int = 30

    // MARK: Generator
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

    private static func handleDateRangePulls(dateRangePulls: DateRangePullsModel, allPulls: [PullModel]) {
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
        print("generate pull stat completed. users: \(pullStat.userPulls.count); pulls: \(pullStat.pulls.count)")
        fetchCommentsToOthers(pullStat: pullStat, allPulls: allPulls, type: .comment).done { _ in
            fetchCommentsToOthers(pullStat: pullStat, allPulls: allPulls, type: .reviewComment).done({ _ in
                pullStat.writeToFile()
            })
        }
    }

    private static func handleAllPagedPulls(dateRanges: [DateRange], pulls: [PullModel]) {
        dateRanges.forEach { dateRange in
            let modelsInThisDateRange = pulls.filter {
                $0.created_at.contains(dateRange.displayText)
            }
            var fetchMultiplePromise: [Promise<[String:Any]>] = []
            modelsInThisDateRange.forEach({ model in
                let promise = ApiRequest<[String:Any]>.getResponsePromise(url: model.url)
                fetchMultiplePromise.append(promise)
            })
            print("fetch all page of pulls(\(fetchMultiplePromise.count))")
            when(fulfilled: fetchMultiplePromise).done({ array in
                print("fetch all page of pulls completed, array = \(array.count)")
                let detailModels = [PullModel].deserialize(from: array)!.compactMap { $0 }
                handleDateRangePulls(dateRangePulls: DateRangePullsModel(dateRange: dateRange, pulls: detailModels), allPulls: pulls)
            }).catch({ error in
                print(error)
            })
        }
    }

    // MARK: Fetchers

    private static func fetchAllPulls(dateRanges: [DateRange]) {
        fetchAllPagedPulls(firstPage: 1, allPagedPulls: AllPagedPullsModel()) { pulls in
            handleAllPagedPulls(dateRanges: dateRanges, pulls: pulls)
        }
    }

    private static func fetchAllPagedPulls(firstPage: Int = 1, allPagedPulls: AllPagedPullsModel, completionHandler: @escaping PullsAction) {
        let url = "https://api.github.com/repos/zillyinc/tellus-ios/pulls?state=all&sort=created&direction=desc&page=\(firstPage)"
        _ = ApiRequest<[Any]>.getResponsePromise(url: url).done { array in
            let models = [PullModel].deserialize(from: array)!.compactMap { $0 }
            allPagedPulls.pulls += models
            let action: String
            if models.count < pageSize {
                completionHandler(allPagedPulls.pulls)
                action = "complete"
            } else {
                fetchAllPagedPulls(firstPage: firstPage + 1, allPagedPulls: allPagedPulls, completionHandler: completionHandler)
                action = "next page"
            }
            print("Request:\(url); result count:\(models.count); \(action)")
        }
    }

    // MARK: Fetchers - Comments

    private static func fetchCommentsToOthers(pullStat: PullStat, allPulls: [PullModel], type: CommentType) -> Promise<Bool> {
        return Promise<Bool> { seal in
            var fetchMultiplePromise: [Promise<[CommentModel]>] = []
            let allPagedComments = AllPagedCommentsModel()
            allPulls.forEach({ model in
                let promise = fetchCommentsToOthersOfOnePull(url: model.commentsUrl(type: type), allPagedComments: allPagedComments)
                fetchMultiplePromise.append(promise)
            })
            print("fetch comments to others - \(type.rawValue) (\(fetchMultiplePromise.count))")
            when(fulfilled: fetchMultiplePromise).done({ array in
                print("fetch comments to others - \(type.rawValue) completed. array: (\(array.count))")
                let allComments = [CommentModel].deserialize(from: array)!.compactMap { $0 }
                var userPulls = pullStat.userPulls
                allComments.forEach({ comment in
                    let user = comment.user.login
                    if userPulls[user] == nil {
                        var userPull = UserPullModel()
                        userPull.user = user
                        userPulls[user] = userPull
                    }
                    userPulls[user]!.comments_to_others[type]! += 1
                })
                seal.fulfill(true)
            }).catch({ error in
                print(error)
                seal.reject(error)
            })
        }
    }

    private static func fetchCommentsToOthersOfOnePull(firstPage: Int = 1, url: String, allPagedComments: AllPagedCommentsModel) -> Promise<[CommentModel]>  {
        return Promise<[CommentModel]> { seal in
            let urlWithPage = url + "?page=\(firstPage)"
            ApiRequest<[Any]>.getResponsePromise(url: urlWithPage).done { array in
                let models = [CommentModel].deserialize(from: array)!.compactMap { $0 }
                allPagedComments.comments += models
                let action: String
                if models.count < pageSize {
                    seal.fulfill(allPagedComments.comments)
                    action = "complete"
                } else {
                    fetchCommentsToOthersOfOnePull(firstPage: firstPage + 1, url: url, allPagedComments: allPagedComments)
                    action = "next page"
                }
                print("Request:\(url); result count:\(models.count); \(action)")
            }
        }
    }
}

