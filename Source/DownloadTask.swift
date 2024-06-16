//
//  DownloadTask.swift
//  FileTransporter
//
//  Created by 刘俊华 on 2023/3/2.
//

import Foundation

typealias DownloadSubscriptionKey = Int64

public struct DownloadTaskCancelToken {
    
    let key: DownloadSubscriptionKey
    
    let url: URL
    
    weak var manager: FileDownloader?
        
    public func cancel() {
        manager?.cancel(token: self)
    }
}


final class DownloadSubscription {
    
    let key: DownloadSubscriptionKey
    let queue: DispatchQueue
    let progress: DownloadProgressHandler?
    let completion: DownloadCompletionHandler?
    let destination: String
    
    init(key: Int64,
         destination: String,
         queue: DispatchQueue,
         progress: DownloadProgressHandler? = nil,
         completion: DownloadCompletionHandler? = nil) {
        self.destination = destination
        self.key = key
        self.queue = queue
        self.progress = progress
        self.completion = completion
    }
}

final class DownloadTask {
    
    public let url: URL
    
    private(set) var currentURL: URL
    
    public let progress: Progress = Progress(totalUnitCount: 0)
    
    private let fileManager = FileManager.default
    
    private let tmpFilePath: String
    
    private var movedDestinations: Set<String> = []
    
    private var subscriptions: [DownloadSubscriptionKey: DownloadSubscription] = [:]

    private let headers: [String: String]?

    weak var manager: FileDownloader?

    private var outputStream: OutputStream?
    
    private var task: URLSessionDataTask?

    private let acceptableStatusCodes: Range<Int> = 200..<300
    
    private var result: Result<String, FileTransporterError>?
    
    private let priority: Float
        
    private let networkServiceType: URLRequest.NetworkServiceType
    
    private let timeoutInterval: TimeInterval

    init(url: URL,
         headers: [String: String]? = nil,
         tmpFilePath: String,
         timeoutInterval: TimeInterval = 60,
         priority: Float = URLSessionTask.defaultPriority,
         networkServiceType: URLRequest.NetworkServiceType = .default) {
        self.url = url
        self.currentURL = url
        self.headers = headers
        self.tmpFilePath = tmpFilePath
        self.timeoutInterval = timeoutInterval
        self.priority = priority
        self.networkServiceType = networkServiceType
    }
    

    
    func start(with session: URLSession, subscription: DownloadSubscription) {

        subscriptions[subscription.key] = subscription
        guard task == nil || task!.state != .running else { return }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.allHTTPHeaderFields = headers
        if let fileInfo = try? fileManager.attributesOfItem(atPath: tmpFilePath), let length = fileInfo[.size] as? Int64 {
            progress.completedUnitCount = length
        }
        request.setValue("bytes=\(progress.completedUnitCount)-", forHTTPHeaderField: "Range")
        request.networkServiceType = networkServiceType
        request.timeoutInterval = 80
        task = session.dataTask(with: request)
        task?.priority = priority
        task?.taskDescription = url.absoluteString
        task?.resume()
    }

    
    func cancel(key: DownloadSubscriptionKey) {

        if let subscription = self.subscriptions.removeValue(forKey: key) {
            subscription.queue.async {
                subscription.completion?(.failure(.cancel))
            }
        }
        if self.subscriptions.isEmpty {
            self._cancel()
        }
    }
    
    private func _cancel() {

        subscriptions.removeAll()
        let isRunning = task?.state == .running
        task?.cancel()
        task = nil
        if !isRunning {
            manager?.didCancelTask(self)
            manager = nil
        }
        
    }
    
    private func isResumedResponse(_ response: HTTPURLResponse) -> Bool {
        response.statusCode == 206
    }
}


extension DownloadTask {
    func didReceive(response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        outputStream?.close()
        outputStream = nil
        result = nil
                
        if subscriptions.isEmpty {
            result = .failure(.subscriptionEmpty)
            completionHandler(.cancel)
            return
        }
        
        guard let response = response as? HTTPURLResponse else {
            result = .failure(.downloadError(.invalidURLResponse(response: response)))
            completionHandler(.cancel)
            return
        }

        guard acceptableStatusCodes.contains(response.statusCode) else {
            result = .failure(.downloadError(.unacceptableStatusCode(response.statusCode)))
            completionHandler(.cancel)
            return
        }
        
        if isResumedResponse(response) {
            outputStream = OutputStream(toFileAtPath: tmpFilePath, append: true)
        } else {
            progress.completedUnitCount = 0
            outputStream = OutputStream(toFileAtPath: tmpFilePath, append: false)
        }
        
        outputStream?.open()
        
        progress.totalUnitCount = response.expectedContentLength + progress.completedUnitCount

        completionHandler(.allow)
    }
    
    func didReceive(dataTask: URLSessionDataTask, data: Data) {
        
        progress.completedUnitCount += Int64(data.count)
        _ = data.withUnsafeBytes { point -> Int in
            guard let buffer = point.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return outputStream?.write(buffer, maxLength: data.count) ?? 0
            
        }

        subscriptions.forEach { (_, subscription) in
            subscription.queue.async {
                subscription.progress?(self.progress)
            }
        }
    }
    
    func didComplete(task: URLSessionTask, error: Error?) {

        outputStream?.close()
        outputStream = nil
        
        if result == nil {
            if let error = error {
                let resultError: FileTransporterError
                if let urlError = error as? URLError, urlError.code == URLError.cancelled {
                    resultError = .cancel
                } else {
                    resultError = .downloadError(.underlying(error: error))
                }
                result = .failure(resultError)
         
            } else {
                result = .success(tmpFilePath)
            }
        }
        
        switch result! {
        case .success:
            subscriptions.forEach { (_, subscription) in
                var result: Result<String, FileTransporterError> = .success(subscription.destination)
                // 如果成功，则把临时文件复制到指定的路径
                if !movedDestinations.contains(subscription.destination) {
                    do {
                        try fileManager.copyItem(atPath: tmpFilePath, toPath: subscription.destination)
                        movedDestinations.insert(subscription.destination)
                    } catch {
                        let response = task.response as? HTTPURLResponse
                        result = .failure(.downloadError(.cannotCopyItem(atPath: tmpFilePath,
                                                                         toPath: subscription.destination,
                                                                         statusCode: response?.statusCode ?? -1,
                                                                         error: error)))
                    }
                }
                subscription.queue.async {
                    subscription.completion?(result)
                }
            }
            try? fileManager.removeItem(atPath: tmpFilePath)
        case let .failure(error):
            let result = self.result!
            subscriptions.forEach { (_, subscription) in
                subscription.queue.async {
                    subscription.completion?(result)
                }
            }
            if case let .downloadError(error) = error,
               case let .unacceptableStatusCode(code) = error,
               code == 416 {
                try? fileManager.removeItem(atPath: tmpFilePath)
            }
        }

        self.result = nil

        _cancel()
    }
}
