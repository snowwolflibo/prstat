//
//  CacheUtility.swift
//  PRStat
//
//  Created by bo li on 2019/7/22.
//  Copyright © 2019 zilly. All rights reserved.
//

import UIKit
import CommonCrypto
import HandyJSON

class CacheUtility: NSObject  {

    static func filePath(url: String) -> String {
        return FileUtility.documentFilePath(for: "cache/" + url.md5() + ".txt")
    }

    static func getData(url: String) -> Any? {
        let path = filePath(url: url)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        let result = try? JSONSerialization.jsonObject(with: data, options: [])
        return result
    }

    static func writeData(url: String, object: Any) {
        let path = filePath(url: url)
        FileUtility.createDirectoryIfNeed(path: path)
        let data = try? JSONSerialization.data(withJSONObject: object, options: []) as? NSData
        data?.write(toFile: path, atomically: true)
    }

}
