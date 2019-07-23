//
//  PRApi.swift
//  PRStat
//
//  Created by bo li on 2019/7/20.
//  Copyright © 2019 zilly. All rights reserved.
//

import PromiseKit

class PullUtility {
    private static let allPagedModelsLock = NSLock()
    private static let modelsAddedLock = NSLock()

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
    class AllPagedCommitsModel {
        var commits: [CommitModel] = []
    }

    typealias PullSummariesAction = ([PullSummaryModel]) -> Void
    typealias CommentsAction = ([CommentModel]) -> Void
    typealias CommitsAction = ([CommitModel]) -> Void

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

    private static func fillUserPulls(pullStatType: PullStatType, stat: Stat, dateRangeAndPulls: DateRangeAndPullsModel, allPulls: [PullSummaryModel]) -> Promise<PullStat> {
        return Promise<PullStat> { seal in
            let pullStat = stat.pullStats.filter { $0.dateRange.displayText == dateRangeAndPulls.dateRange.displayText }.first!
            if pullStatType == .created {
                pullStat.createdPulls = dateRangeAndPulls.pulls
            }
            dateRangeAndPulls.pulls.forEach({ pull in
                guard let user = pull.user?.login else { return }
                if pullStat.userPulls[pullStatType]![user] == nil {
                    var userPull = UserPullModel()
                    userPull.user = user
                    pullStat.userPulls[pullStatType]![user] = userPull
                }
                pullStat.userPulls[pullStatType]![user]?.pulls.append(pull)
            })
            if pullStatType == .created {
                print("generate pull stat (\(pullStat.dateRange.displayText)) completed. users: \(pullStat.userPulls.count); pulls: \(pullStat.createdPulls.count)")
            }
            seal.fulfill(pullStat)
        }
    }

    // MARK: Fetchers
    private static func fetchAllPullsCommentsAndWriteToFile(repository: Repository, dateRanges: [DateRange]) {
        print("begin fetch all pulls==============")
        fetchAllPagedPulls(repository: repository, firstPage: 1, allPagedPullSummaries: AllPagedPullSummarysModel()) { allPulls in
            print("end fetch all pulls \(allPulls.count)==============")
            let stat = Stat()
            stat.pullStats = dateRanges.map { PullStat(dateRange: $0, userLineAndComments: [:], createdPulls: []) }
            _  = fetchAllPullDetails(pullStatType: .created, stat: stat, dateRanges: dateRanges, allPulls: allPulls).done({ pullStats in
                _  = fetchAllPullDetails(pullStatType: .merged, stat: stat, dateRanges: dateRanges, allPulls: allPulls).done({ pullStats in
                    _  = fetchCommits(stat: stat, allPulls: allPulls).done({ _ in
                        _  = fetchCommentsToOthers(stat: stat, allPulls: allPulls, type: .comment).done { _ in
                            _  = fetchCommentsToOthers(stat: stat, allPulls: allPulls, type: .reviewComment).done({ _ in
                                pullStats.forEach({ pullStat in
                                    pullStat.writeToFile(repository: repository)
                                })
                            })
                        }
                    })

                })
            })
        }
    }

    private static func fetchAllPullDetails(pullStatType: PullStatType, stat: Stat, dateRanges: [DateRange], allPulls: [PullSummaryModel]) -> Promise<[PullStat]> {
        var promises = [Promise<PullStat>]()
        dateRanges.forEach { dateRange in
            let promise = Promise<PullStat> { seal in
                let modelsInThisDateRange = allPulls.filter {
                    switch pullStatType {
                    case .created:
                        return $0.created_at.contains(dateRange.displayText)
                    case .merged:
                        return ($0.merged_at?.contains(dateRange.displayText) ?? false)
                    }
                }
                var fetchMultiplePromise: [Promise<[String:Any]>] = []
                modelsInThisDateRange.forEach({ model in
                    print("fetch \(model.url)")
                    let promise = ApiRequest<[String:Any]>.getResponsePromise(forceFetchFromServer: true, url: model.url)
                    fetchMultiplePromise.append(promise)
                })
                print("fetch all pulls in \(dateRange.displayText) (\(fetchMultiplePromise.count))")
                when(fulfilled: fetchMultiplePromise).done({ array in
                    print("fetch all pulls in \(dateRange.displayText) completed, array = \(array.count)")
                    let detailModels = [PullModel].deserialize(from: array)!.compactMap { $0 }
                    _  = fillUserPulls(pullStatType: pullStatType, stat: stat, dateRangeAndPulls: DateRangeAndPullsModel(dateRange: dateRange, pulls: detailModels), allPulls: allPulls).done({ pullStat in
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

    private static func fetchAllPagedPulls(repository: Repository, firstPage: Int = 1, allPagedPullSummaries: AllPagedPullSummarysModel, completionHandler: @escaping PullSummariesAction) {
        let url = "https://api.github.com/repos/zillyinc/\(repository.rawValue)/pulls?state=all&sort=created&direction=desc&page=\(firstPage)"
        _ = ApiRequest<[Any]>.getResponsePromise(forceFetchFromServer: true, url: url).done { array in
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

    private static func fetchCommentsToOthers(stat: Stat, allPulls: [PullSummaryModel], type: CommentType) -> Promise<Bool> {
        return Promise<Bool> { seal in
            print("fetch comments to others - \(type.rawValue) (\(allPulls.count))")
            _  = fetchCommentsToOthersWithBatch(stat: stat, type: type, allPulls: allPulls, page: 0).done({ result in
                seal.fulfill(result)
            })
        }
    }

    private static func fetchCommentsToOthersWithBatch(stat: Stat, type: CommentType, allPulls: [PullSummaryModel], page: Int) -> Promise<Bool> {
        return Promise<Bool> { seal in
//            let pageSize = 20
//            let pageCount = (allPulls.count - 1) / pageSize + 1
//            if page >= pageCount {
//                seal.fulfill(true)
//                return
//            }
//            let pickedPulls = pick(from: allPulls, page: page, pageSize: pageSize)
            var fetchMultiplePromise: [Promise<[CommentModel]>] = []
            allPulls.forEach({ model in
                let promise = fetchCommentsToOthersOfOnePull(url: model.commentsUrl(type: type), allPagedComments: AllPagedCommentsModel())
                fetchMultiplePromise.append(promise)
            })
            when(fulfilled: fetchMultiplePromise).done({ array in
                let allComments = array.flatMap { $0 }
                print("fetch comments to others - \(type.rawValue) completed. allComments: (\(allComments.count))")
                allComments.forEach({ comment in
                    let user = comment.user.login
                    modelsAddedLock.lock()
                    if let commit_id = comment.original_commit_id {
                        if stat.allCommits[commit_id] != nil {
                            stat.allCommits[commit_id]!.review_comments += 1
                            print("\(user) add comment to \(stat.allCommits[commit_id]!.author.login)'s commit \(commit_id) review_comments = \(stat.allCommits[commit_id]!.review_comments) comment_id:\(comment.id!)")
                        }
                    }
                    let pullStat = stat.pullStats.filter { comment.created_at.contains($0.dateRange.displayText) }.first
                    if let pullStat = pullStat {
                        if pullStat.userLineAndComments[user] == nil {
                            var userLineAndComment = UserLineAndCommentModel()
                            userLineAndComment.user = user
                            pullStat.userLineAndComments[user] = userLineAndComment
                        }
                        pullStat.userLineAndComments[user]!.comments_to_others[type]! += 1
                    }
                    modelsAddedLock.unlock()
                })
                seal.fulfill(true)
//                _  = fetchCommentsToOthersWithBatch(pullStats: pullStats, type: type, allPulls: allPulls, page: page + 1).done({ result in
//                    seal.fulfill(result)
//                })
            }).catch({ error in
                print(error)
                seal.reject(error)
            })
        }
    }

    private static func fetchCommentsToOthersOfOnePull(firstPage: Int = 1, url: String, allPagedComments: AllPagedCommentsModel) -> Promise<[CommentModel]>  {
        return Promise<[CommentModel]> { seal in
            let urlWithPage = url + "?page=\(firstPage)"
            _  = ApiRequest<[Any]>.getResponsePromise(url: urlWithPage).done { array in
                let models = [CommentModel].deserialize(from: array)!.compactMap { $0 }
                allPagedModelsLock.lock()
                allPagedComments.comments += models
                allPagedModelsLock.unlock()
                let block = { (action: String) in
                    print("Request:\(url); result count:\(models.count); \(action)")
                }
                if models.count < pageSize {
                    block("completed")
                    seal.fulfill(allPagedComments.comments)
                } else {
                    block("go next page")
                    _  = fetchCommentsToOthersOfOnePull(firstPage: firstPage + 1, url: url, allPagedComments: allPagedComments).done({ models in
                        seal.fulfill(models)
                    })
                }
            }
        }
    }

    // MARK: Fetcher - Commits
    private static func fetchCommits(stat: Stat, allPulls: [PullSummaryModel]) -> Promise<Bool> {
        return Promise<Bool> { seal in
            print("fetch commits of pulls (\(allPulls.count))")
            fetchCommitsWithBatch(stat: stat, allPulls: allPulls, page: 0).done({ result in
                seal.fulfill(result)
            }).catch({ error in
                print(error)
                seal.fulfill(true)
            })
        }
    }

    private static func fetchCommitsWithBatch(stat: Stat, allPulls: [PullSummaryModel], page: Int) -> Promise<Bool> {
        return Promise<Bool> { seal in
            var fetchMultiplePromise: [Promise<[CommitModel]>] = []
            allPulls.forEach({ model in
                let promise = fetchCommitsOfOnePull(url: model.commits_url, allPagedCommits: AllPagedCommitsModel())
                fetchMultiplePromise.append(promise)
            })
            when(fulfilled: fetchMultiplePromise).done({ array in
                let allCommits = array.flatMap { $0 }
                print("fetch commits completed. v: (\(allCommits.count))")
                allCommits.forEach({ commit in
                    let user = commit.author.login
                    modelsAddedLock.lock()
                    stat.allCommits[commit.sha] = commit
                    let pullStat = stat.pullStats.filter { commit.commit.committer.date.contains($0.dateRange.displayText) }.first
                    if let pullStat = pullStat {
                        if pullStat.userLineAndComments[user] == nil {
                            var userLineAndComment = UserLineAndCommentModel()
                            userLineAndComment.user = user
                            pullStat.userLineAndComments[user] = userLineAndComment
                        }
//                        pullStat.userLineAndComments[user]!.comment_count += commit.commit.comment_count
                        if !commit.commit.message.starts(with: "Merge branch") {
                            pullStat.userLineAndComments[user]!.commits.append(commit)
                            pullStat.userLineAndComments[user]!.commit_count += 1
                            pullStat.userLineAndComments[user]!.additions += commit.stats?.additions ?? 0
                            pullStat.userLineAndComments[user]!.deletions += commit.stats?.deletions ?? 0
                            print("lines \(user) additions = \(pullStat.userLineAndComments[user]!.additions) deletions = \(pullStat.userLineAndComments[user]!.deletions)\t\t added: \(commit.stats?.deletions ?? 0)\t\t \(commit.stats?.additions ?? 0)\t\t \(commit.sha!)")
                        }
                    }
                    modelsAddedLock.unlock()
                })
                seal.fulfill(true)
            }).catch({ error in
                print(error)
                seal.fulfill(true)
            })
        }
    }

    private static func fetchCommitsOfOnePull(firstPage: Int = 1, url: String, allPagedCommits: AllPagedCommitsModel) -> Promise<[CommitModel]>  {
        return Promise<[CommitModel]> { seal in
            let urlWithPage = url + "?page=\(firstPage)"
            ApiRequest<[Any]>.getResponsePromise(forceFetchFromServer: true, url: urlWithPage).done { array in
                let models = [CommitModel].deserialize(from: array)!.compactMap { $0 }
                allPagedModelsLock.lock()
                allPagedCommits.commits += models
                allPagedModelsLock.unlock()
                let block = { (action: String) in
                    print("Request:\(url); result count:\(models.count) allPagedCommits.commits:\(allPagedCommits.commits.count); \(action)")
                }
                if models.count < pageSize {
                    block("completed")
                    fetchCommitsBySHA(commits: allPagedCommits.commits).done({ _ in
//                        fetchCommitReviewComments(commits: allPagedCommits.commits).done({ _ in
//                            seal.fulfill(allPagedCommits.commits)
//                        })
                        seal.fulfill(allPagedCommits.commits)
                    }).catch({ error in
                        seal.reject(error)
                    })

                } else {
                    block("go next page")
                    fetchCommitsOfOnePull(firstPage: firstPage + 1, url: url, allPagedCommits: allPagedCommits).done({ models in
                        seal.fulfill(models)
                    }).catch({ error in
                        seal.reject(error)
                    })
                }
                }.catch({ error in
                    seal.reject(error)
                })
        }
    }

    // MARK: Fetcher - Commits - SHA
    private static func fetchCommitsBySHA(commits: [CommitModel]) -> Promise<Bool> {
        print("begin fetchCommitsBySHA")
        return Promise<Bool> { seal in
            var fetchMultiplePromise: [Promise<Bool>] = []
            commits.forEach({ model in
                let promise = fetchCommitBySHA(commit: model)
                fetchMultiplePromise.append(promise)
            })
            when(fulfilled: fetchMultiplePromise).done { _ in
                seal.fulfill(true)
                }.catch({ error in
                    print(error)
                    seal.fulfill(true)
                })
        }
    }


    private static func fetchCommitBySHA(commit: CommitModel) -> Promise<Bool>  {
        return Promise<Bool> { seal in
            ApiRequest<[String:Any]>.getResponsePromise(url: commit.url).done { data in
                if let model = CommitModel.deserialize(from: data), let stats = model.stats {
                    allPagedModelsLock.lock()
                    commit.stats = stats
                    commit.commit = model.commit
                    allPagedModelsLock.unlock()
                    print("Request:\(commit.url!); \(stats.displayText)")
                } else {
                    print("Request:\(commit.url!); return nil \(data)")
                }
                seal.fulfill(true)
                }.catch({ error in
                    print(error)
                    seal.fulfill(true)
                })
        }
    }

//    // MARK: Fetcher - Commits - Review Comments
//    private static func fetchCommitReviewComments(commits: [CommitModel]) -> Promise<Bool> {
//        print("begin fetchCommitReviewComments")
//        return Promise<Bool> { seal in
//            var fetchMultiplePromise: [Promise<Bool>] = []
//            commits.forEach({ model in
//                let promise = fetchCommitReviewComment(commit: model)
//                fetchMultiplePromise.append(promise)
//            })
//            when(fulfilled: fetchMultiplePromise).done { _ in
//                seal.fulfill(true)
//                }.catch({ error in
//                    print(error)
//                    seal.fulfill(true)
//                })
//        }
//    }
//
//    private static func fetchCommitReviewComment(commit: CommitModel) -> Promise<Bool>  {
//        return Promise<Bool> { seal in
//            let url = commit.comments_url!
//            ApiRequest<[Any]>.getResponsePromise(url: url).done { data in
//                if let models = [CommentModel].deserialize(from: data) {
//                    allPagedModelsLock.lock()
//                    commit.commit.comment_count = models.compactMap { $0 }.count
//                    allPagedModelsLock.unlock()
//                    print("Request:\(url); commit.commit.comment_count \(commit.commit.comment_count)")
//                } else {
//                    print("Request:\(url); return nil")
//                }
//                seal.fulfill(true)
//                }.catch({ error in
//                    print(error)
//                    seal.fulfill(true)
//                })
//        }
//    }
}

