//
//  FileUtility.swift
//  MythWOW
//
//  Created by bo li on 2019/7/7.
//  Copyright © 2019 snowwolf. All rights reserved.
//

import UIKit

/// 文件工具类
class FileUtility {

    /// 获取资源文件的完整路径
    ///
    /// - Parameter name: 文件名
    /// - Returns: 完整路径
    static func filePath(forResource name: String) -> String {
        return Bundle.main.path(forResource: name, ofType: nil)!
    }

    /// 获取Document文件的完整路径
    ///
    /// - Parameter name: 文件名
    /// - Returns: 完整路径
    static func documentFilePath(for name: String) -> String {
        return NSHomeDirectory() + "/Documents/" + name
    }

    /// 读取文本文本内容
    ///
    /// - Parameter name: 资源文件名
    /// - Returns: 文本内容
    static func readText(fromResource name: String) -> String? {
        return try? String(contentsOf: URL(fileURLWithPath: filePath(forResource: name)), encoding: .utf8)
    }
}
