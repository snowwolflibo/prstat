//
//  Extension.swift
//  PRStat
//
//  Created by bo li on 2019/7/23.
//  Copyright © 2019 zilly. All rights reserved.
//

import UIKit

func formatted(_ value: Float) -> String {
    return String(format: "%.2f", value)
}

extension Int {
    var commaString: String {
        return "\(self)".commaString
    }
}

extension Float {
    var commaString: String {
        return "\(self)".commaString
    }
}

extension String  {
    // MARK : 添加千分位的函数实现
    var commaString: String {
        // 判断传入参数是否有值
        if self.count != 0 {
            /**
             创建两个变量
             integerPart : 传入参数的整数部分
             decimalPart : 传入参数的小数部分
             */
            var integerPart:String?
            var decimalPart = String.init()

            // 先将传入的参数整体赋值给整数部分
            integerPart =  self
            // 然后再判断是否含有小数点(分割出整数和小数部分)
            if self.contains(".") {
                let segmentationArray = self.components(separatedBy: ".")
                integerPart = segmentationArray.first
                decimalPart = segmentationArray.last!
            }

            /**
             创建临时存放余数的可变数组
             */
            let remainderMutableArray = NSMutableArray.init(capacity: 0)
            // 创建一个临时存储商的变量
            var discussValue:Int32 = 0

            /**
             对传入参数的整数部分进行千分拆分
             */
            repeat {
                let tempValue = integerPart! as NSString
                // 获取商
                discussValue = tempValue.intValue / 1000
                // 获取余数
                let remainderValue = tempValue.intValue % 1000
                // 将余数一字符串的形式添加到可变数组里面
                let remainderStr = String.init(format: "%d", remainderValue)
                remainderMutableArray.insert(remainderStr, at: 0)
                // 将商重新复制
                integerPart = String.init(format: "%d", discussValue)
            } while discussValue>0

            // 创建一个临时存储余数数组里的对象拼接起来的对象
            var tempString = String.init()

            // 根据传入参数的小数部分是否存在，是拼接“.” 还是不拼接""
            let lastKey = (decimalPart.count == 0 ? "":".")
            /**
             获取余数组里的余数
             */
            for i in 0..<remainderMutableArray.count {
                // 判断余数数组是否遍历到最后一位
                let  param = (i != remainderMutableArray.count-1 ?",":lastKey)
                tempString = tempString + String.init(format: "%@%@", remainderMutableArray[i] as! String,param)
            }
            //  清楚一些数据
            integerPart = nil
            remainderMutableArray.removeAllObjects()
            // 最后返回整数和小数的合并
            return tempString as String + decimalPart
        }
        return self
    }
}
