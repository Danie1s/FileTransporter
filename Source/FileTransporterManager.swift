//
//  FileTransporterManager.swift
//  FileTransporter
//
//  Created by 刘俊华 on 2023/3/2.
//

import Foundation
import Collections

open class FileTransporterManager {
    
    
    private struct CacheInfo {
        let fileExists: Bool
        let fileName: String
        let destination: String
    }
    
    private struct State {
        var currentTokenID: Int64 = 0
        var maxConcurrentTasksLimit: Int = .max
        var vaildateFileErrorHandler: ((URL, String) -> Bool)?
    }
    
    public let identifier: String
        
    public let downloader: FileDownloader
    
    public let cache: Cache
    
    let rootQueue: DispatchQueue
    
    private var tasks: [LoadRequest: LoadTask] = [:]

    private var pendingTasks: OrderedDictionary<LoadRequest, LoadTask> = [:]

    @Protected
    private var protectedState = State()
    
    public let logger: Logable
    
    public var maxConcurrentTasksLimit: Int {
        get { protectedState.maxConcurrentTasksLimit }
        set { protectedState.maxConcurrentTasksLimit = newValue }
    }
    
    /// 当文件校验失败时，是否保留文件
    /// 会在子线程中执行
    public var vaildateFileErrorHandler: ((URL, String) -> Bool)? {
        get { protectedState.vaildateFileErrorHandler }
        set { protectedState.vaildateFileErrorHandler = newValue }
    }
    
    
    public init(identifier: String,
                configuration: SessionConfiguration = SessionConfiguration(),
                maxConcurrentTasksLimit: Int = 6,
                logger: Logable? = nil,
                downloader: FileDownloader? = nil ,
                cache: Cache? = nil,
                rootQueue: DispatchQueue? = nil) {
        self.identifier = identifier
        self.rootQueue = rootQueue ?? DispatchQueue(label: "com.FileTransporter.FileTransporterManager.rootQueue.\(identifier)")
        let underlyingQueue = DispatchQueue(label: "com.FileTransporter.FileDownloader.underlyingQueue.\(identifier)", target: self.rootQueue)
        let defaultCache = cache ?? Cache(identifier: identifier)
        self.downloader = downloader ?? FileDownloader(identifier: identifier, configuration: configuration, tmpFileDirectoryPath: defaultCache.tmpFileDirectoryPath, underlyingQueue: underlyingQueue, logger: logger)
        self.cache = defaultCache
        self.logger = logger ?? Logger(identifier: identifier, level: .default)
        self.protectedState.maxConcurrentTasksLimit = maxConcurrentTasksLimit
    }
    

    
    @discardableResult
    open func loadFile(with request: LoadRequest,
                       queue: DispatchQueue = .main,
                       progress: LoadProgressHandler? = nil,
                       completion: LoadCompletionHandler? = nil) -> LoadTaskCancelToken {
        $protectedState.write { $0.currentTokenID += 1 }
        let currentTokenID = protectedState.currentTokenID
        
        let subscription = LoadTaskSubscription(key: currentTokenID, queue: queue, progress: progress, completion: completion)
        rootQueue.async {
            self.scheduleTask(request: request, subscription: subscription)
        }
        var token = LoadTaskCancelToken(key: currentTokenID, request: request)
        token.manager = self
        return token
        
    }
    
    private func scheduleTask(request: LoadRequest, subscription: LoadTaskSubscription) {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        let info = getCacheInfo(request: request)
        let destination = info.destination
        
        if info.fileExists {
            logger.log(.info, message: "load file from disk, url: \(request.url)")

            subscription.queue.async {
                subscription.completion?(.success(LoadResponse(destination: destination, isCache: true)))
            }
            return
        }
        

        if let task = tasks[request] ?? pendingTasks[request] {
            task.appendSubscription(subscription)
            return
        }
        
        let task = LoadTask(request: request)
        task.manager = self
        task.appendSubscription(subscription)
        
        if shouldPerformNextTask() {
            tasks[request] = task
            performTask(task, cacheInfo: info)
        } else {
            pendingTasks[request] = task
        }
    }
    
    private func shouldPerformNextTask() -> Bool {
        dispatchPrecondition(condition: .onQueue(rootQueue))
        
        return tasks.count < protectedState.maxConcurrentTasksLimit
    }
    
    private func performNextTaskIfNeeded() {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        guard shouldPerformNextTask() else { return }
        if !pendingTasks.isEmpty {
            let task = pendingTasks.removeFirst()
            tasks[task.key] = task.value
            performTask(task.value, cacheInfo: nil)
        }
    }
    
    private func getCacheInfo(request: LoadRequest) -> CacheInfo {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        let fileName = request.fileName ?? type(of: cache).fileName(url: request.url)
        let destination = cache.filePath(fileName: fileName) ?? ""
        let fileExists: Bool = cache.fileExists(atPath: destination)
        
        return CacheInfo(fileExists: fileExists, fileName: fileName, destination: destination)
    }
    
    private func performTask(_ task: LoadTask, cacheInfo: CacheInfo?) {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        let request = task.request
        
        let info = cacheInfo ?? getCacheInfo(request: request)
        let destination = info.destination
        
        // 因为有队列的存在，所以真正执行的时候，需要再次判断本地是否有缓存
        if info.fileExists {
            logger.log(.info, message: "load file from disk, url: \(request.url)")

            task.executeCompletionHandler(.success(LoadResponse(destination: destination, isCache: true)))

            return
        }
                
        var run = false
        
        logger.log(.info, message: "load file from network, url: \(request.url)")

        let downloadRequest = DownloadRequest(url: request.url,
                                              headers: request.headers,
                                              destination: destination,
                                              timeoutInterval: request.timeoutInterval,
                                              priority: request.priority,
                                              networkServiceType: request.networkServiceType)
        // 下载
        let token = downloader.download(with: downloadRequest,
                                        queue: rootQueue) { [weak self, weak task] progress in
            guard let self = self else { return }

            task?.executeProgressHandler(progress)
            if !run {
                run.toggle()
                self.logger.log(.info, message: "downloading, url: \(request.url)")
            }
        } completion: { [weak self, weak task] result in

            switch result {
            case let .success(destination):
                #warning("磁盘满的情况")
                
                self?.validateFileIfNeeded(request: request, filePath: destination) { result in
                    guard let self = self else { return }
                    switch result {
                    case .success:
                        self.logger.log(.info, message: "download file succeed, url: \(request.url)")
                        task?.executeCompletionHandler(.success(LoadResponse(destination: destination, isCache: false)))

                    case let .failure(error):
                        self.logger.log(.error, message: "download file failed, url: \(request.url), error: \(error)")
                        if self.vaildateFileErrorHandler?(request.url, destination) == true {
                        } else {
                            self.cache.removeFile(path: destination)
                        }
                        task?.executeCompletionHandler(.failure(error))
                    }
                }
 
            case let .failure(error):
                self?.logger.log(.error, message: "download file failed, url: \(request.url), error: \(error)")
                task?.executeCompletionHandler(.failure(error))
            }
            
        }
        task.token = token
    }
    
    private func validateFileIfNeeded(request: LoadRequest, filePath: String, completion: @escaping (Result<Void, FileTransporterError>) -> Void) {
        dispatchPrecondition(condition: .onQueue(rootQueue))
        
        if let verificationType = request.verificationType {
            FileChecksumHelper.validateFile(filePath, type: verificationType, queue: rootQueue) { result in
                completion(result)
            }
        } else {
            completion(.success(()))
        }
    }
    
    
}

extension FileTransporterManager {
    
    func cancel(token: LoadTaskCancelToken) {
        rootQueue.async {
            let task = self.tasks[token.request] ?? self.pendingTasks[token.request]
            task?.cancel(key: token.key)
        }
    }
    
    func didCancelTask(_ task: LoadTask) {
        dispatchPrecondition(condition: .onQueue(rootQueue))

        tasks[task.request] = nil
        pendingTasks[task.request] = nil

        rootQueue.asyncAfter(deadline: .now() + 0.1) {
            self.performNextTaskIfNeeded()
        }
        
    }

}
