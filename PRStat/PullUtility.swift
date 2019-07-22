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
        for i in 0..<1 {
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
        print("generate pull stat (\(pullStat.dateRange.displayText)) completed. users: \(pullStat.userPulls.count); pulls: \(pullStat.pulls.count)")
//        pullStat.writeToFile()
        fetchCommentsToOthers(pullStat: pullStat, allPulls: allPulls, type: .comment).done { _ in
            fetchCommentsToOthers(pullStat: pullStat, allPulls: allPulls, type: .reviewComment).done({ _ in
                pullStat.writeToFile()
            })
        }
    }

    private static func handleAllPagedPulls(dateRanges: [DateRange], allPulls: [PullModel]) {
        dateRanges.forEach { dateRange in
            autoreleasepool {
                let modelsInThisDateRange = allPulls.filter {
                    $0.created_at.contains(dateRange.displayText)
                }
                var fetchMultiplePromise: [Promise<[String:Any]>] = []
                modelsInThisDateRange.forEach({ model in
                    let promise = ApiRequest<[String:Any]>.getResponsePromise(url: model.url)
                    fetchMultiplePromise.append(promise)
                })
                print("fetch all pulls in \(dateRange.displayText) (\(fetchMultiplePromise.count))")
                when(fulfilled: fetchMultiplePromise).done({ array in
                    print("fetch all pulls in \(dateRange.displayText) completed, array = \(array.count)")
                    autoreleasepool {
                        let detailModels = [PullModel].deserialize(from: array)!.compactMap { $0 }
                        handleDateRangePulls(dateRangePulls: DateRangePullsModel(dateRange: dateRange, pulls: detailModels), allPulls: allPulls)
                    }
                }).catch({ error in
                    print(error)
                })
            }
        }
    }

    // MARK: Fetchers

    private static func fetchAllPulls(dateRanges: [DateRange]) {
        print("begin fetch all pulls==============")
        fetchAllPagedPulls(firstPage: 1, allPagedPulls: AllPagedPullsModel()) { pulls in
            print("end fetch all pulls \(pulls.count)==============")
            handleAllPagedPulls(dateRanges: dateRanges, allPulls: pulls)
        }
    }

    private static func fetchAllPagedPulls(firstPage: Int = 1, allPagedPulls: AllPagedPullsModel, completionHandler: @escaping PullsAction) {
        let url = "https://api.github.com/repos/zillyinc/tellus-ios/pulls?state=all&sort=created&direction=desc&page=\(firstPage)"
        _ = ApiRequest<[Any]>.getResponsePromise(url: url).done { array in
            autoreleasepool {
                let models = [PullModel].deserialize(from: array)!.compactMap { $0 }
                allPagedPulls.pulls += models
                let block = { (action: String) in
                    print("Request:\(url); result count:\(models.count); \(action)")
                }
                if models.count < pageSize {
                    block("complete")
                    completionHandler(allPagedPulls.pulls)
                } else {
                    block("next page")
                    fetchAllPagedPulls(firstPage: firstPage + 1, allPagedPulls: allPagedPulls, completionHandler: completionHandler)
                }
            }
        }
    }

    // MARK: Fetchers - Comments

    private static func pick(from array: [PullModel], page: Int, pageSize: Int) -> [PullModel] {
        let start = pageSize * page
        let end = min(array.count, pageSize * (page + 1))
        var result: [PullModel] = []
        print("pick pull from \(start) to \(end - 1), total: \(array.count)")
        for i in start..<end {
            result.append(array[i])
        }
        return result
    }

    private static func fetchCommentsToOthers(pullStat: PullStat, allPulls: [PullModel], type: CommentType) -> Promise<Bool> {
        return Promise<Bool> { seal in
            print("fetch comments to others - \(type.rawValue) (\(allPulls.count))")
            fetchCommentsToOthersWithBatch(pullStat: pullStat, type: type, allPulls: allPulls, page: 0).done({ result in
                seal.fulfill(result)
            })
        }
    }

    private static let allPagedCommentsLock = NSLock()
    private static let commentsAddedLock = NSLock()
    private static func fetchCommentsToOthersWithBatch(pullStat: PullStat, type: CommentType, allPulls: [PullModel], page: Int) -> Promise<Bool> {
        return Promise<Bool> { seal in
            let pageSize = 20
            let pageCount = (allPulls.count - 1) / pageSize + 1
            if page >= pageCount {
                seal.fulfill(true)
                return
            }
            let pickedPulls = pick(from: allPulls, page: page, pageSize: pageSize)
            var fetchMultiplePromise: [Promise<[CommentModel]>] = []
            pickedPulls.forEach({ model in
                let promise = fetchCommentsToOthersOfOnePull(url: model.commentsUrl(type: type), allPagedComments: AllPagedCommentsModel())
                fetchMultiplePromise.append(promise)
            })

            when(fulfilled: fetchMultiplePromise).done({ array in
                let allComments = array.flatMap { $0 }
                print("fetch comments to others - \(type.rawValue) completed. allComments: (\(allComments.count))")
                allComments.forEach({ comment in
                    let user = comment.user.login
                    commentsAddedLock.lock()
                    if pullStat.userPulls[user] == nil {
                        var userPull = UserPullModel()
                        userPull.user = user
                        pullStat.userPulls[user] = userPull
                    }
                    pullStat.userPulls[user]!.comments_to_others[type]! += 1
                    commentsAddedLock.unlock()
                })
                fetchCommentsToOthersWithBatch(pullStat: pullStat, type: type, allPulls: allPulls, page: page + 1).done({ result in
                    seal.fulfill(result)
                })
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
                allPagedCommentsLock.lock()
                allPagedComments.comments += models
                allPagedCommentsLock.unlock()
                let block = { (action: String) in
                    print("Request:\(url); result count:\(models.count); \(action)")
                }
                if models.count < pageSize {
                    block("complete")
                    seal.fulfill(allPagedComments.comments)
                } else {
                    block("next page")
                    fetchCommentsToOthersOfOnePull(firstPage: firstPage + 1, url: url, allPagedComments: allPagedComments).done({ models in
                        seal.fulfill(models)
                    })
                }
            }
        }
    }
}

