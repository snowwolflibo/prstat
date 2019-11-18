//
//  ApiHelper.swift
//  Whisky
//
//  Created by bo li on 2018/3/19.
//  Copyright © 2018年 bo li. All rights reserved.
//

import UIKit
import PromiseKit

class ApiRequest<ModelType> {
  
    // MARK: - -Promise
    public static func getResponsePromise(forceFetchFromServer: Bool = false, url: String, method: HTTPMethod = .get, body: Parameters? = nil, querys: Parameters? = nil) -> Promise<ModelType> {
        if (!forceFetchFromServer || Config.alwaysUseCache), let data = CacheUtility.getData(url: url) {
            return Promise<ModelType> { seal in seal.fulfill(data as! ModelType) }
        } else {
            return getResponsePromiseBase(url: url, method: method, body: body, querys: querys, requestAlamofireAction: { (requestParameter) -> DataRequest in
                return Alamofire.request(requestParameter.getURL(), method: method, parameters: requestParameter.body, encoding: URLEncoding.default, headers: requestParameter.headers)
            })
        }
    }

    static func getRequestParameter(url: String, body: Parameters? = nil, querys: Parameters? = nil) -> ApiRequestParameter {
        let requestParameter = ApiRequestParameter(url: url, body: body, querys: querys)
        let url2 = requestParameter.getURL()
        let body2 = String(describing: requestParameter.body)
        let headers2 = String(describing: requestParameter.headers)
        LogUtility.log("【Api数据】url=" + url2)
        LogUtility.log("【Api数据】body=\(body2))")
        LogUtility.log("【Api数据】headers=\(headers2)")
        return requestParameter
    }

    @discardableResult
    static func getResponsePromiseBase(url: String, method: HTTPMethod, body: Parameters?, querys: Parameters?, requestAlamofireAction: @escaping (_ requestParameter:  ApiRequestParameter) -> DataRequest) -> Promise<ModelType> {
        let requestParameter = getRequestParameter(url: url, body: body, querys: querys)
        let dataRequest = requestAlamofireAction(requestParameter)
        let promise = firstly { dataRequest.responseJSON() }.map(on: nil) { data in return resovleJSONToResponse(url: url, json: data.json) }
        _  = dataRequest.responseString().done(on: nil, { data in LogUtility.log("【Api数据】responseString:\(data.string)") })
        promise.catch { error in printError(error: error, dataRequest: dataRequest) }
        return promise
    }

    private static func resovleJSONToResponse(url: String, json: Any) -> ModelType {
        let array: ModelType = json as! ModelType
        CacheUtility.writeData(url: url, object: json)
        LogUtility.log("从服务端返回的数据:\n\(String(describing: array))")
        return array
    }

    private static func printError(error: Error?, dataRequest: DataRequest?) {
        if let _error = error { LogUtility.log("promise.catch:\(_error)") }
    }
}
