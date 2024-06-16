//
//  Cache.swift
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

open class Cache {

    private let ioQueue: DispatchQueue
    
    private var debouncer: Debouncer
    
    public let containerDirectoryPath: String

    public let tmpFileDirectoryPath: String
    
    public let fileDirectoryPath: String
    
    public let identifier: String
        
    private let fileManager = FileManager.default
            
    private var swept = false
    
    public let logger: Logable
    

    public static func defaultDiskCachePathClosure(_ cacheName: String) -> String {
        let dstPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        return (dstPath as NSString).appendingPathComponent(cacheName)
    }

    
    /// 初始化方法
    /// - Parameters:
    ///   - identifier: 不同的 identifier 代表不同的下载模块
    ///   - containerDirectoryPath: 用于存放下载中的缓存文件和下载完成的文件的目录。如果没有自定义目录，Cache 会提供默认的目录，这些目录跟 identifier 相关
    ///   - tmpFileDirectoryPath: 用于存在下载中的缓存文件。如果没有自定义目录，Cache 会提供默认的目录
    ///   - fileDirectoryPath: 用于存在下载完成的文件。如果没有自定义目录，Cache 会提供默认的目录
    ///   - logger: 用于打印信息
    public init(identifier: String,
                containerDirectoryPath: String? = nil,
                tmpFileDirectoryPath: String? = nil,
                fileDirectoryPath: String? = nil, logger: Logable? = nil) {
        self.identifier = identifier
        
        let ioQueueName = "com.FileTransporter.Cache.ioQueue.\(identifier)"
        ioQueue = DispatchQueue(label: ioQueueName)
        
        debouncer = Debouncer(queue: ioQueue)
        
        let cacheName = "com.FileTransporter.Cache.\(identifier)"
        
        let diskCachePath = Self.defaultDiskCachePathClosure(cacheName)
                
        let path = containerDirectoryPath ?? (diskCachePath as NSString).appendingPathComponent("Downloads")
                
        self.containerDirectoryPath = path

        self.tmpFileDirectoryPath = tmpFileDirectoryPath ?? (path as NSString).appendingPathComponent("Tmp")
        
        self.fileDirectoryPath = fileDirectoryPath ?? (path as NSString).appendingPathComponent("File")
        
        self.logger = logger ?? Logger(identifier: identifier, level: .default)
        
        ioQueue.sync {
            createDirectorys()
        }

    }
    
    private func createDirectorys() {
        dispatchPrecondition(condition: .onQueue(ioQueue))

        if !fileManager.fileExists(atPath: containerDirectoryPath) {
            do {
                try fileManager.createDirectory(atPath: containerDirectoryPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                logger.log(.error, message: "create container directory failed")
            }
        }
        
        if !fileManager.fileExists(atPath: tmpFileDirectoryPath) {
            do {
                try fileManager.createDirectory(atPath: tmpFileDirectoryPath, withIntermediateDirectories: true, attributes: nil)
            } catch  {
                logger.log(.error, message: "create temp directory failed")
            }
        }
        
        if !fileManager.fileExists(atPath: fileDirectoryPath) {
            do {
                try fileManager.createDirectory(atPath: fileDirectoryPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                logger.log(.error, message: "create file directory failed")
            }
        }
    }
    
    // 返回 url 对应的文件名
    open class func fileName(url: URL) -> String {
        var fileName = url.absoluteString.ft.md5
        if !url.pathExtension.isEmpty {
            fileName += ".\(url.pathExtension)"
        }
        return fileName
    }
    
    
    private func sweepFileNames(at directoryPath: String) -> [String]? {
        dispatchPrecondition(condition: .onQueue(ioQueue))
        guard let url = URL(string: fileDirectoryPath) else { return nil }
        do {
            let urls = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.nameKey])
            let fileNames: [String] = try urls.compactMap { try $0.resourceValues(forKeys: [.nameKey]).name }
            return fileNames
        } catch {
            logger.log(.error, message: "cache sweep directory failed, error: \(error)")
            return nil
        }
    }
    
    
    private func execute(queue: DispatchQueue,
                         result: Result<Void, FileTransporterError>,
                         completion: ((Result<Void, FileTransporterError>) -> Void)? = nil) {
        if let completion = completion {
            queue.async {
                completion(result)
            }
        }
    }
}


// MARK: - file
extension Cache {

    func filePath(fileName: String) -> String? {
        if fileName.isEmpty {
            return nil
        }
        let path = (fileDirectoryPath as NSString).appendingPathComponent(fileName)
        return path
    }
    
    
    func tmpFilePath(fileName: String) -> String? {
        if fileName.isEmpty {
            return nil
        }
        let path = (tmpFileDirectoryPath as NSString).appendingPathComponent(fileName)
        return path
    }
    

    
    // 返回 url 对应的下载文件路径
    public func filePath(url: URL) -> String? {
        let fileName = Self.fileName(url: url)
        return filePath(fileName: fileName)
    }
    
    // 返回 url 对应的下载中缓存文件路径
    public func tmpFilePath(url: URL) -> String? {
        let fileName = Self.fileName(url: url)
        return tmpFilePath(fileName: fileName)
    }
    
    
    func fileExists(atPath path: String) -> Bool {
        ioQueue.sync {
            fileManager.fileExists(atPath: path)
        }
    }
    

    
    public func moveItem(at srcURL: URL, to dstURL: URL) throws {
        try ioQueue.sync {
            do {
                try fileManager.moveItem(at: srcURL, to: dstURL)
            } catch {
                self.logger.log(.error, message: "moveItem file failed, error: \(error)")
                let newError = FileTransporterError.cacheError(reason: .cannotMoveItem(atPath: srcURL.absoluteString,
                                                                                       toPath: dstURL.absoluteString,
                                                                                       error: error))
                throw newError
            }
        }
    }
}




// MARK: - remove
extension Cache {
    public func removeFile(url: URL, queue: DispatchQueue = .main, completion: ((Result<Void, FileTransporterError>) -> Void)? = nil) {
        ioQueue.async {
            let fileName = Self.fileName(url: url)
            
            if let filePath = self.filePath(fileName: fileName),
               self.fileManager.fileExists(atPath: filePath) {
                do {
                    try self.fileManager.removeItem(atPath: filePath)
                    self.execute(queue: queue, result: .success(()), completion: completion)
                } catch {
                    self.logger.log(.error, message: "remove file failed, error: \(error)")
                    let newError = FileTransporterError.cacheError(reason: .cannotRemoveItem(path: filePath, error: error))
                    self.execute(queue: queue, result: .failure(newError), completion: completion)
                }
            } else {
                self.execute(queue: queue, result: .success(()), completion: completion)

            }
        }
    }
    
    public func removeFile(path: String, queue: DispatchQueue = .main, completion: ((Result<Void, FileTransporterError>) -> Void)? = nil) {
        ioQueue.async {
            if self.fileManager.fileExists(atPath: path) {
                do {
                    try self.fileManager.removeItem(atPath: path)
                    self.execute(queue: queue, result: .success(()), completion: completion)
                } catch {
                    self.logger.log(.error, message: "remove file failed, error: \(error)")
                    let newError = FileTransporterError.cacheError(reason: .cannotRemoveItem(path: path, error: error))
                    self.execute(queue: queue, result: .failure(newError), completion: completion)

                }
            } else {
                self.execute(queue: queue, result: .success(()), completion: completion)

            }
        }
    }
    

    public func removeTmpFile(url: URL, queue: DispatchQueue = .main, completion: ((Result<Void, FileTransporterError>) -> Void)? = nil) {
        ioQueue.async {
            let fileName = Self.fileName(url: url)
            let path = (self.tmpFileDirectoryPath as NSString).appendingPathComponent(fileName)
            if self.fileManager.fileExists(atPath: path) {
                do {
                    try self.fileManager.removeItem(atPath: path)
                    self.execute(queue: queue, result: .success(()), completion: completion)
                } catch {
                    self.logger.log(.error, message: "remove temp file failed, error: \(error)")
                    let newError = FileTransporterError.cacheError(reason: .cannotRemoveItem(path: path, error: error))
                    self.execute(queue: queue, result: .failure(newError), completion: completion)
                }
            } else {
                self.execute(queue: queue, result: .success(()), completion: completion)

            }

        }
    }
    
    public func removeAllTmpFiles(queue: DispatchQueue = .main, completion: ((Result<Void, FileTransporterError>) -> Void)? = nil) {
        ioQueue.async {
            do {
                try self.fileManager.removeItem(atPath: self.tmpFileDirectoryPath)
                self.createDirectorys()
            } catch {
                self.logger.log(.error, message: "remove temp directory failed, error: \(error)")
                let newError = FileTransporterError.cacheError(reason: .cannotRemoveItem(path: self.tmpFileDirectoryPath, error: error))
                self.execute(queue: queue, result: .failure(newError), completion: completion)
            }
        }
    }
    
    public func clearDiskCache(queue: DispatchQueue = .main, completion: ((Result<Void, FileTransporterError>) -> Void)? = nil) {
        ioQueue.async {
            do {
                try self.fileManager.removeItem(atPath: self.containerDirectoryPath)
                self.createDirectorys()
                self.execute(queue: queue, result: .success(()), completion: completion)
            } catch {
                self.logger.log(.error, message: "clear disk cache failed, error: \(error)")

                let newError = FileTransporterError.cacheError(reason: .cannotRemoveItem(path: self.containerDirectoryPath, error: error))
                self.execute(queue: queue, result: .failure(newError), completion: completion)
            }
  
        }
    }
}
