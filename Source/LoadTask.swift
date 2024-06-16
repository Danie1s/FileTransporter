//
//  LoadTask.swift
//  FileTransporter
//
//  Created by 刘俊华 on 2023/3/5.
//

import Foundation

public struct LoadTaskCancelToken {
    
    let key: LoadTaskSubscriptionKey
    
    let request: LoadRequest
    
    weak var manager: FileTransporterManager?
        
    public func cancel() {
        manager?.cancel(token: self)
    }
}

typealias LoadTaskSubscriptionKey = Int64

final class LoadTaskSubscription {
    
    let key: LoadTaskSubscriptionKey
    let queue: DispatchQueue
    let progress: LoadProgressHandler?
    let completion: LoadCompletionHandler?
    
    init(key: LoadTaskSubscriptionKey,
         queue: DispatchQueue,
         progress: LoadProgressHandler? = nil,
         completion: LoadCompletionHandler? = nil) {
        self.key = key
        self.queue = queue
        self.progress = progress
        self.completion = completion
    }
}

public struct LoadResponse {
    public let destination: String
    public let isCache: Bool
}

public typealias LoadProgressHandler = (Progress) -> Void

public typealias LoadCompletionHandler = (Result<LoadResponse, FileTransporterError>) -> Void


final class LoadTask {
    
    weak var manager: FileTransporterManager?
    
    let request: LoadRequest

    private var subscriptions: [LoadTaskSubscriptionKey: LoadTaskSubscription] = [:]
    
    var token: DownloadTaskCancelToken?

    init(request: LoadRequest) {
        self.request = request
    }
    
    
    func appendSubscription(_ subscription: LoadTaskSubscription) {
        subscriptions[subscription.key] = subscription
    }
    
    func executeProgressHandler(_ progress: Progress) {
        subscriptions.forEach { (_, subscription) in
            subscription.queue.async {
                subscription.progress?(progress)
            }
        }
    }
    
    func executeCompletionHandler(_ result: Result<LoadResponse, FileTransporterError>) {
        subscriptions.forEach { (_, subscription) in
            subscription.queue.async {
                subscription.completion?(result)
            }
        }
        _cancel()
    }
    
    func cancel(key: LoadTaskSubscriptionKey) {
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
        token?.cancel()
        token = nil
        manager?.didCancelTask(self)
        manager = nil
    }
    
    
}
