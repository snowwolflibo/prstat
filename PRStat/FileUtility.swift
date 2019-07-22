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

    static func readText(filePath: String) -> String? {
        return try? String(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8)
    }

    static func createDirectoryIfNeed(path: String) {
        let lastLinePos = path.positionOf(sub: "/", backwards: true)
        let folderPath = path.subString(start: 0, length: lastLinePos)
        let fileManager = FileManager.default
        try! fileManager.createDirectory(atPath: folderPath,
                                         withIntermediateDirectories: true, attributes: nil)
    }
}

extension String {
    //返回第一次出现的指定子字符串在此字符串中的索引
    //（如果backwards参数设置为true，则返回最后出现的位置）
    func positionOf(sub:String, backwards:Bool = false)->Int {
        var pos = -1
        if let range = range(of:sub, options: backwards ? .backwards : .literal ) {
            if !range.isEmpty {
                pos = self.distance(from:startIndex, to:range.lowerBound)
            }
        }
        return pos
    }

    //根据开始位置和长度截取字符串
    func subString(start:Int, length:Int = -1) -> String {
        let str = self as NSString
        if str.length > 0 {
            if start >= 0 {
                var len = length
                if len == -1 {
                    len = str.length - start
                }
                len = min(len, str.length)
                return str.substring(with: NSRange(location: start, length: len))
            }
        }
        return ""
    }

    func toRange(_ range: NSRange) -> Range<String.Index>? {
        guard let from16 = utf16.index(utf16.startIndex, offsetBy: range.location, limitedBy: utf16.endIndex) else { return nil }
        guard let to16 = utf16.index(from16, offsetBy: range.length, limitedBy: utf16.endIndex) else { return nil }
        guard let from = String.Index(from16, within: self) else { return nil }
        guard let to = String.Index(to16, within: self) else { return nil }
        return from ..< to
    }

}
