//
//  ApiHelper.swift
//  Whisky
//
//  Created by bo li on 2018/3/19.
//  Copyright © 2018年 bo li. All rights reserved.
//

import UIKit
import PromiseKit
import HandyJSON


class FileData {
    var data: Data!
    var name: String!
    var fileName: String!
    var mimeType: String!
}

class ApiRequest<ModelType> {

    // MARK: - -Promise



    public static func post(url: String, body: Parameters? = nil) -> Promise<ModelType>  {
        return getResponsePromiseBase(url: url, method: .post, body: body, querys: nil, requestAlamofireAction: { (requestParameter) -> DataRequest in
            return Alamofire.request(requestParameter.getURL(), method: .post, parameters: body, encoding: JSONEncoding.default, headers: requestParameter.headers)
        })
    }

    public static func getResponsePromise(url: String, method: HTTPMethod = .get, body: Parameters? = nil, querys: Parameters? = nil) -> Promise<ModelType> {
        return getResponsePromiseBase(url: url, method: method, body: body, querys: querys, requestAlamofireAction: { (requestParameter) -> DataRequest in
            return Alamofire.request(requestParameter.getURL(), method: method, parameters: requestParameter.body, encoding: URLEncoding.default, headers: requestParameter.headers)
        })
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
        let promise = firstly {
            dataRequest.responseJSON()
            }.map(on: nil) { data in
                return resovleJSONToResponse(json: data.json)
        }
        dataRequest.responseString().done(on: nil, { data in
            LogUtility.log("【Api数据】responseString:\(data.string)")
        })
        promise.catch { (error) in
            printError(error: error, dataRequest: dataRequest)
        }
        return promise
    }

    private static func resovleJSONToResponse(json: Any) -> ModelType {
        let array: ModelType = json as! ModelType

        LogUtility.log("从服务端返回的数据:\n\(String(describing: array))")
        return array
    }

//    private static func getErrorWSResponse(error: Error?) -> ResponseType {
//        var strError = ""
//        if let _error = error {
//            strError = "; \(_error)"
//            print("调用接口失败\(_error)")
//        }
//        let res = ResponseType()
//        res.code = -1
//        res.message = "deserialize error" + strError
//        return res
//    }

    private static func printError(error: Error?, dataRequest: DataRequest?) {
        if let _error = error {
            LogUtility.log("promise.catch:\(_error)")
        }
    }

}
