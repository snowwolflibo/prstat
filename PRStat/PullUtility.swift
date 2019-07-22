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

    struct DateRangeAndPullsModel {
        var dateRange: DateRange
        var pulls: [PullModel]
    }

    class AllPagedPullSummarysModel {
        var pulls: [PullSummaryModel] = []
    }

    class AllPagedCommentsModel {
        var comments: [CommentModel] = []
    }

    typealias PullSummariesAction = ([PullSummaryModel]) -> Void

    typealias CommentsAction = ([CommentModel]) -> Void

    // MARK: Variable

    private static let pageSize: Int = 30

    // MARK: Generator
    static func generatePullStats(repository: Repository) {
        let today = Date()
        let calendar = Calendar(identifier: .gregorian)
        var dateRanges: [DateRange] = []
        for i in 0..<2 {
            var monthAdded = DateComponents()
            monthAdded.month = -i
            let newDate = calendar.date(byAdding: monthAdded, to: today)!
            dateRanges.append(DateRange(year: calendar.component(.year, from: newDate), month: calendar.component(.month, from: newDate)))
        }
        fetchAllPullsCommentsAndWriteToFile(repository: repository, dateRanges: dateRanges)
    }

    private static func fillUserPulls(dateRangeAndPulls: DateRangeAndPullsModel, allPulls: [PullSummaryModel]) -> Promise<PullStat> {
        return Promise<PullStat> { seal in
            let pullStat = PullStat(dateRange: dateRangeAndPulls.dateRange, userPulls: [:], pulls: dateRangeAndPulls.pulls)
            dateRangeAndPulls.pulls.forEach({ pull in
                guard let user = pull.user?.login else { return }
                if pullStat.userPulls[user] == nil {
                    var userPull = UserPullModel()
                    userPull.user = user
                    pullStat.userPulls[user] = userPull
                }
                pullStat.userPulls[user]?.pulls.append(pull)
            })
            print("generate pull stat (\(pullStat.dateRange.displayText)) completed. users: \(pullStat.userPulls.count); pulls: \(pullStat.pulls.count)")
            seal.fulfill(pullStat)
        }
    }

    private static func fetchAllPullDetails(dateRanges: [DateRange], allPulls: [PullSummaryModel]) -> Promise<[PullStat]> {
        var promises = [Promise<PullStat>]()
        dateRanges.forEach { dateRange in
            let promise = Promise<PullStat> { seal in
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
                    let detailModels = [PullModel].deserialize(from: array)!.compactMap { $0 }
                    fillUserPulls(dateRangeAndPulls: DateRangeAndPullsModel(dateRange: dateRange, pulls: detailModels), allPulls: allPulls).done({ pullStat in
                        seal.fulfill(pullStat)
                    })
                }).catch({ error in
                    print(error)
                })
            }
            promises.append(promise)
        }
        return when(fulfilled: promises)
    }

    // MARK: Fetchers

    private static func fetchAllPullsCommentsAndWriteToFile(repository: Repository, dateRanges: [DateRange]) {
        print("begin fetch all pulls==============")
        fetchAllPagedPulls(repository: repository, firstPage: 1, allPagedPullSummaries: AllPagedPullSummarysModel()) { allPulls in
            print("end fetch all pulls \(allPulls.count)==============")
            fetchAllPullDetails(dateRanges: dateRanges, allPulls: allPulls).done({ pullStats in
//                fetchCommentsToOthers(pullStats: pullStats, allPulls: allPulls, type: .comment).done { _ in
//                    fetchCommentsToOthers(pullStats: pullStats, allPulls: allPulls, type: .reviewComment).done({ _ in
//                        pullStats.forEach({ pullStat in
//                            pullStat.writeToFile()
//                        })
//                    })
//                }
                pullStats.forEach({ pullStat in
                    pullStat.writeToFile()
                })
            })

        }
    }

    private static func fetchAllPagedPulls(repository: Repository, firstPage: Int = 1, allPagedPullSummaries: AllPagedPullSummarysModel, completionHandler: @escaping PullSummariesAction) {
        let url = "https://api.github.com/repos/zillyinc/\(repository.rawValue)/pulls?state=all&sort=created&direction=desc&page=\(firstPage)"
        _ = ApiRequest<[Any]>.getResponsePromise(url: url).done { array in
            autoreleasepool {
                let models = [PullSummaryModel].deserialize(from: array)!.compactMap { $0 }
                allPagedPullSummaries.pulls += models
                let block = { (action: String) in
                    print("Request:\(url); result count:\(models.count); \(action)")
                }
                if models.count < pageSize {
                    block("completed")
                    completionHandler(allPagedPullSummaries.pulls)
                } else {
                    block("go next page")
                    fetchAllPagedPulls(repository: repository, firstPage: firstPage + 1, allPagedPullSummaries: allPagedPullSummaries, completionHandler: completionHandler)
                }
            }
        }
    }

    // MARK: Fetchers - Comments

    private static func pick(from array: [PullSummaryModel], page: Int, pageSize: Int) -> [PullSummaryModel] {
        let start = pageSize * page
        let end = min(array.count, pageSize * (page + 1))
        var result: [PullSummaryModel] = []
        print("pick pull from \(start) to \(end - 1), total: \(array.count)")
        for i in start..<end {
            result.append(array[i])
        }
        return result
    }

    private static func fetchCommentsToOthers(pullStats: [PullStat], allPulls: [PullSummaryModel], type: CommentType) -> Promise<Bool> {
        return Promise<Bool> { seal in
            print("fetch comments to others - \(type.rawValue) (\(allPulls.count))")
            fetchCommentsToOthersWithBatch(pullStats: pullStats, type: type, allPulls: allPulls, page: 0).done({ result in
                seal.fulfill(result)
            })
        }
    }

    private static let allPagedCommentsLock = NSLock()
    private static let commentsAddedLock = NSLock()
    private static func fetchCommentsToOthersWithBatch(pullStats: [PullStat], type: CommentType, allPulls: [PullSummaryModel], page: Int) -> Promise<Bool> {
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
                    let pullStat = pullStats.filter { comment.created_at.contains($0.dateRange.displayText) }.first
                    if let pullStat = pullStat {
                        if pullStat.userPulls[user] == nil {
                            var userPull = UserPullModel()
                            userPull.user = user
                            pullStat.userPulls[user] = userPull
                        }
                        pullStat.userPulls[user]!.comments_to_others[type]! += 1
                    }

                    commentsAddedLock.unlock()
                })
                fetchCommentsToOthersWithBatch(pullStats: pullStats, type: type, allPulls: allPulls, page: page + 1).done({ result in
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
                    block("completed")
                    seal.fulfill(allPagedComments.comments)
                } else {
                    block("go next page")
                    fetchCommentsToOthersOfOnePull(firstPage: firstPage + 1, url: url, allPagedComments: allPagedComments).done({ models in
                        seal.fulfill(models)
                    })
                }
            }
        }
    }
}

