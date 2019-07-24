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
    class AllPagedModels<T> {
        var models: [T] = []
    }

    typealias ModelsAction<T> = ([T]) -> Void

    // MARK: Generator
    static func generatePullStats(repository: Repository) {
        let today = Date()
        let calendar = Calendar(identifier: .gregorian)
        var dateRanges: [DateRange] = []
        for i in 0..<5 {
            var monthAdded = DateComponents()
            monthAdded.month = -i
            let newDate = calendar.date(byAdding: monthAdded, to: today)!
            dateRanges.append(DateRange(year: calendar.component(.year, from: newDate), month: calendar.component(.month, from: newDate)))
        }
        // Create a Stat object to store all pull relative data
        let stat = Stat(dateRanges: dateRanges)
        fetchPullStatsAndWriteToFile(repository: repository, dateRanges: dateRanges, stat: stat)
    }

    // MARK: Fetchers
    private static func fetchPullStatsAndWriteToFile(repository: Repository, dateRanges: [DateRange], stat: Stat) {
        print("begin fetch all pulls==============")
        fetchAllPagedPulls(repository: repository, page: 1, allPagedPullSummaries: AllPagedModels<PullSummaryModel>()) { allPulls in
            print("end fetch all pulls \(allPulls.count)==============")
            _  = fetchAllPullDetails(pullStatType: .created, stat: stat, dateRanges: dateRanges, allPulls: allPulls).done({ pullStats in
                _  = fetchAllPullDetails(pullStatType: .merged, stat: stat, dateRanges: dateRanges, allPulls: allPulls).done({ pullStats in
                    let allPullsWithDetail = pullStats.compactMap { $0.createdPulls }.flatMap { $0 }
                    _ = fetchReviewsOfAllPulls(repository: repository, stat: stat, allPulls: allPullsWithDetail).done({ _ in
                        _  = fetchCommits(stat: stat, allPulls: allPulls).done({ _ in
                            _  = fetchCommentsToOthersOfAllPulls(stat: stat, allPulls: allPulls, type: .comment).done { _ in
                                _  = fetchCommentsToOthersOfAllPulls(stat: stat, allPulls: allPulls, type: .reviewComment).done({ _ in
                                    pullStats.forEach({ pullStat in pullStat.writeToFile(repository: repository) })
                                })
                            }
                        })
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
                    case .created: return $0.created_at.contains(dateRange.displayText)
                    case .merged: return ($0.merged_at?.contains(dateRange.displayText) ?? false)
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
                    _  = fillUserPullsIntoStat(pullStatType: pullStatType, stat: stat, dateRange: dateRange, allPullsWithDetail: detailModels).done({ pullStat in seal.fulfill(pullStat) })
                }).catch({ error in print(error) })
            }
            promises.append(promise)
        }
        return when(fulfilled: promises)
    }

    private static func fillUserPullsIntoStat(pullStatType: PullStatType, stat: Stat, dateRange: DateRange, allPullsWithDetail: [PullModel]) -> Promise<PullStat> {
        return Promise<PullStat> { seal in
            let pullStat = stat.pullStats.filter { $0.dateRange.displayText == dateRange.displayText }.first!
            if pullStatType == .created {
                pullStat.createdPulls = allPullsWithDetail
            }
            allPullsWithDetail.forEach({ pull in
                guard let user = pull.true_user?.login else { return }
                if pullStat.userPulls[pullStatType]![user] == nil {
                    let userPull = UserPullModel(user: user)
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

    private static func fetchAllPagedPulls(repository: Repository, page: Int = 1, allPagedPullSummaries: AllPagedModels<PullSummaryModel>, completionHandler: @escaping ModelsAction<PullSummaryModel>) {
        let url = Config.pullsUrl(repository: repository, page: page)
        _ = ApiRequest<[Any]>.getResponsePromise(forceFetchFromServer: true, url: url).done { array in
            let models = [PullSummaryModel].deserialize(from: array)!.compactMap { $0 }
            allPagedPullSummaries.models += models
            let block = { (action: String) in
                print("Request:\(url); result count:\(models.count); \(action)")
            }
            if models.count < Config.pageSize {
                block("completed")
                completionHandler(allPagedPullSummaries.models)
            } else {
                block("go next page")
                fetchAllPagedPulls(repository: repository, page: page + 1, allPagedPullSummaries: allPagedPullSummaries, completionHandler: completionHandler)
            }
        }
    }

    // MARK: Fetchers - Comments
    private static func fetchCommentsToOthersOfAllPulls(stat: Stat, allPulls: [PullSummaryModel], type: CommentType) -> Promise<Bool> {
        print("fetch comments to others of all pulls - \(type.rawValue) (\(allPulls.count))")
        return Promise<Bool> { seal in
            var fetchMultiplePromise: [Promise<[CommentModel]>] = []
            allPulls.forEach({ model in
                let promise = fetchCommentsToOthersOfOnePull(url: model.commentsUrl(type: type), allPagedModels: AllPagedModels<CommentModel>())
                fetchMultiplePromise.append(promise)
            })
            when(fulfilled: fetchMultiplePromise).done({ array in
                let allModels = array.flatMap { $0 }
                print("fetch comments to others - \(type.rawValue) completed. allModels: (\(allModels.count))")
                allModels.forEach({ comment in
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
                            pullStat.userLineAndComments[user] = UserLineAndCommentModel(user: user)
                        }
                        pullStat.userLineAndComments[user]!.comments_to_others[type]! += 1
                    }
                    modelsAddedLock.unlock()
                })
                seal.fulfill(true)
            }).catch({ error in
                print(error)
                seal.reject(error)
            })
        }
    }

    private static func fetchCommentsToOthersOfOnePull(page: Int = 1, url: String, allPagedModels: AllPagedModels<CommentModel>) -> Promise<[CommentModel]>  {
        return Promise<[CommentModel]> { seal in
            let urlWithPage = url + "?page=\(page)"
            _  = ApiRequest<[Any]>.getResponsePromise(forceFetchFromServer: true, url: urlWithPage).done { array in
                let models = [CommentModel].deserialize(from: array)!.compactMap { $0 }
                allPagedModelsLock.lock()
                allPagedModels.models += models
                allPagedModelsLock.unlock()
                let block = { (action: String) in
                    print("Request:\(url); result count:\(models.count); \(action)")
                }
                if models.count < Config.pageSize {
                    block("completed")
                    seal.fulfill(allPagedModels.models)
                } else {
                    block("go next page")
                    _  = fetchCommentsToOthersOfOnePull(page: page + 1, url: url, allPagedModels: allPagedModels).done({ models in
                        seal.fulfill(models)
                    })
                }
            }
        }
    }

    // MARK: Fetcher - Reviews
    private static func fetchReviewsOfAllPulls(repository: Repository, stat: Stat, allPulls: [PullModel]) -> Promise<Bool> {
        print("fetch reviews of all pulls (\(allPulls.count))")
        return Promise<Bool> { seal in
            var fetchMultiplePromise: [Promise<[ReviewModel]>] = []
            allPulls.forEach({ model in
                let promise = fetchReviewsOfOnePull(stat: stat, pull: model, url: Config.reviewsUrl(repository: repository, pullNumber: model.number), allPagedModels: AllPagedModels<ReviewModel>())
                fetchMultiplePromise.append(promise)
            })
            when(fulfilled: fetchMultiplePromise).done({ array in
                seal.fulfill(true)
            }).catch({ error in
                print(error)
                seal.reject(error)
            })
        }
    }

    private static func fetchReviewsOfOnePull(stat: Stat, pull: PullModel, page: Int = 1, url: String, allPagedModels: AllPagedModels<ReviewModel>) -> Promise<[ReviewModel]>  {
        return Promise<[ReviewModel]> { seal in
            let urlWithPage = url + "?page=\(page)"
            _  = ApiRequest<[Any]>.getResponsePromise(forceFetchFromServer: true, url: urlWithPage).done { array in
                let models = [ReviewModel].deserialize(from: array)!.compactMap { $0 }
                if models.count > 0 {
                    allPagedModelsLock.lock()
                    allPagedModels.models += models
                    print("add reviews to \(pull.true_user?.login ?? "")'s pull \(pull.number)  total reviews = \(allPagedModels.models.count) added reviews:\(models.count) \(pull.html_url) \(urlWithPage)")
                    allPagedModelsLock.unlock()
                }
                let block = { (action: String) in
                    print("Request:\(url); result count:\(models.count); \(action)")
                }
                if models.count < Config.pageSize {
                    block("completed")
                    pull.reviews = allPagedModels.models.count
                    stat.pullStats.forEach({ pullStat in
                        let pullsOfUser = pullStat.userPulls[.merged]?.values.flatMap({ $0.pulls })
                        pullsOfUser?.filter({ $0.number == pull.number }).forEach({ pullOfUser in
                            pullOfUser.reviews = pull.reviews
                        })
                    })
                    seal.fulfill(allPagedModels.models)
                } else {
                    block("go next page")
                    _  = fetchReviewsOfOnePull(stat: stat, pull: pull, page: page + 1, url: url, allPagedModels: allPagedModels).done({ result in
                        seal.fulfill(result)
                    })
                }
            }
        }
    }

    // MARK: Fetcher - Commits
    private static func fetchCommits(stat: Stat, allPulls: [PullSummaryModel]) -> Promise<Bool> {
        return Promise<Bool> { seal in
            print("fetch commits of pulls (\(allPulls.count))")
            fetchCommitsWithBatch(stat: stat, allPulls: allPulls).done({ result in
                seal.fulfill(result)
            }).catch({ error in
                print(error)
                seal.fulfill(true)
            })
        }
    }

    private static func fetchCommitsWithBatch(stat: Stat, allPulls: [PullSummaryModel]) -> Promise<Bool> {
        return Promise<Bool> { seal in
            var fetchMultiplePromise: [Promise<[CommitModel]>] = []
            allPulls.forEach({ model in
                let promise = fetchCommitsOfOnePull(url: model.commits_url, allPagedCommits: AllPagedModels<CommitModel>())
                fetchMultiplePromise.append(promise)
            })
            when(fulfilled: fetchMultiplePromise).done({ array in
                let allCommits = array.flatMap { $0 }
                print("fetch commits completed. v: (\(allCommits.count))")
                allCommits.forEach({ commit in
                    if let user = commit.author?.login {
                        modelsAddedLock.lock()
                        stat.allCommits[commit.sha] = commit
                        // Determine whether the date range is based on the commit date
                        let pullStat = stat.pullStats.filter { commit.commit.committer.date.contains($0.dateRange.displayText) }.first
                        if let pullStat = pullStat {
                            if !commit.commit.message.starts(with: "Merge branch") {
                                if pullStat.userLineAndComments[user] == nil {
                                    pullStat.userLineAndComments[user] = UserLineAndCommentModel(user: user)
                                }
                                pullStat.userLineAndComments[user]!.commits.append(commit)
                                pullStat.userLineAndComments[user]!.additions += commit.stats?.additions ?? 0
                                pullStat.userLineAndComments[user]!.deletions += commit.stats?.deletions ?? 0
                                print("lines \(user) additions = \(pullStat.userLineAndComments[user]!.additions) deletions = \(pullStat.userLineAndComments[user]!.deletions)\t\t added: \(commit.stats?.deletions ?? 0)\t\t \(commit.stats?.additions ?? 0)\t\t \(commit.sha!)")
                            }
                        }
                        modelsAddedLock.unlock()
                    }
                })
                seal.fulfill(true)
            }).catch({ error in
                print(error)
                seal.fulfill(true)
            })
        }
    }

    private static func fetchCommitsOfOnePull(page: Int = 1, url: String, allPagedCommits: AllPagedModels<CommitModel>) -> Promise<[CommitModel]>  {
        return Promise<[CommitModel]> { seal in
            let urlWithPage = url + "?page=\(page)"
            ApiRequest<[Any]>.getResponsePromise(forceFetchFromServer: true, url: urlWithPage).done { array in
                let models = [CommitModel].deserialize(from: array)!.compactMap { $0 }
                allPagedModelsLock.lock()
                allPagedCommits.models += models
                allPagedModelsLock.unlock()
                let block = { (action: String) in
                    print("Request:\(url); result count:\(models.count) allPagedCommits.commits:\(allPagedCommits.models.count); \(action)")
                }
                if models.count < Config.pageSize {
                    block("completed")
                    fetchCommitsBySHA(commits: allPagedCommits.models).done({ _ in
                        seal.fulfill(allPagedCommits.models)
                    }).catch({ error in
                        seal.reject(error)
                    })

                } else {
                    block("go next page")
                    fetchCommitsOfOnePull(page: page + 1, url: url, allPagedCommits: allPagedCommits).done({ models in
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
}

