//
//  Common.swift
//  FileTransporter
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation


public enum LogLevel {
    case `default`
    case error
    case none
}

public enum LogType {
    case info
    case error
}

public protocol Logable: AnyObject {
    var identifier: String { get }

    var level: LogLevel { get set }

    func log(_ type: LogType, message: String)
}

open class Logger: Logable {

    public let identifier: String

    public var level: LogLevel

    public init(identifier: String, level: LogLevel) {
        self.identifier = identifier
        self.level = level
    }
    
    open func log(_ type: LogType, message: String) {
        if level == .none {
            return
        }
        if level == .error && type == .info {
            return
        }
        var strings = ["************************ FileTransporterLog ************************"]
        strings.append("identifier    :  \(identifier)")
        switch type {
        case .info:
            strings.append("message       :  \(message)")
        case .error:
            strings.append("error         :  \(message)")
        }
        strings.append("thread        :  \(Thread.current)")
        strings.append("")
        print(strings.joined(separator: "\n"))
    }
}



public struct FileTransporterWrapper<Base> {
    let base: Base
    init(_ base: Base) {
        self.base = base
    }
}


public protocol FileTransporterCompatible {

}

extension FileTransporterCompatible {
    public var ft: FileTransporterWrapper<Self> {
        get { FileTransporterWrapper(self) }
    }
    public static var ft: FileTransporterWrapper<Self>.Type {
        get { FileTransporterWrapper<Self>.self }
    }
}

