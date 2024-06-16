//
//  FileDownloader.swift
//  FileTransporter
//
//  Created by 刘俊华 on 2023/3/2.
//

import Foundation

public typealias DownloadProgressHandler = (Progress) -> Void

public typealias DownloadCompletionHandler = (Result<(String), FileTransporterError>) -> Void

public typealias ChallengeHandler = (URLSessionTask, URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void

open class FileDownloader {
    
    private struct State {
        var currentTokenID: Int64 = 0
        var challengeHandler: ChallengeHandler?
    }

    let identifier: String
    
    let underlyingQueue: DispatchQueue
    
    let tmpFileDirectoryPath: String
    
    let logger: Logable
    
    public let monitor: NetworkMonitor
    
    private var tasks: [URL: DownloadTask] = [:]
        
    @Protected
    private var protectedState: State
    
    // tls 握手处理
    public var challengeHandler: ChallengeHandler? {
        get { protectedState.challengeHandler }
        set { protectedState.challengeHandler = newValue }
    }
    
    private var configuration: SessionConfiguration

    private var session: URLSession?

    /// 初始化方法
    /// 注意：需要保证 tmpFileDirectoryPath 的目录是存在的
    public init(identifier: String,
                configuration: SessionConfiguration = SessionConfiguration(),
                tmpFileDirectoryPath: String,
                underlyingQueue: DispatchQueue? = nil,
                logger: Logable? = nil,
                monitors: [NetworkMonitor] = []) {
        self.identifier = identifier
        self.underlyingQueue = underlyingQueue ?? DispatchQueue(label: "com.FileTransporter.FileDownloader.underlyingQueue.\(identifier)")
        self.protectedState = State()
        self.configuration = configuration
        self.tmpFileDirectoryPath = tmpFileDirectoryPath
        self.logger = logger ?? Logger(identifier: identifier, level: .default)
        monitor = CompositeNetworkMonitor(monitors: monitors)
    }
    
    deinit {
        let session = self.session
        underlyingQueue.async {
            session?.invalidateAndCancel()
        }
    }
    
    
    open func download(with request: DownloadRequest,
                       queue: DispatchQueue = .main,
                       progress: DownloadProgressHandler? = nil,
                       completion: DownloadCompletionHandler? = nil) -> DownloadTaskCancelToken {
        
        $protectedState.write { $0.currentTokenID += 1 }
        let currentTokenID = protectedState.currentTokenID
        
        let subscription = DownloadSubscription(key: currentTokenID, destination: request.destination, queue: queue, progress: progress, completion: completion)
        let tmpFilePath = (tmpFileDirectoryPath as NSString).appendingPathComponent(Cache.fileName(url: request.url))
//        underlyingQueue.async {
            self.scheduleTask(request: request, tmpFilePath: tmpFilePath, subscription: subscription)
//        }
        
        var token = DownloadTaskCancelToken(key: currentTokenID, url: request.url)
        token.manager = self
        return token
    }
    
    private func createSessionIfNeeded() {
//        dispatchPrecondition(condition: .onQueue(underlyingQueue))
        
        guard session == nil else { return }
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.httpMaximumConnectionsPerHost = 100000
        sessionConfiguration.allowsCellularAccess = configuration.allowsCellularAccess
        if #available(iOS 13, macOS 10.15, *) {
            sessionConfiguration.allowsConstrainedNetworkAccess = configuration.allowsConstrainedNetworkAccess
            sessionConfiguration.allowsExpensiveNetworkAccess = configuration.allowsExpensiveNetworkAccess
        }
        
        let delegateQueue = OperationQueue(maxConcurrentOperationCount: 1,
                                           underlyingQueue: underlyingQueue,
                                           name: "com.FileTransporter.FileDownloader.delegateQueue.\(identifier)")
        let delegate = SessionDelegate()
        delegate.manager = self
        delegate.monitor = monitor
        session = URLSession(configuration: sessionConfiguration,
                                delegate: delegate,
                                delegateQueue: delegateQueue)
    }
    
    private func scheduleTask(request: DownloadRequest,
                              tmpFilePath: String,
                              subscription: DownloadSubscription) {
//        dispatchPrecondition(condition: .onQueue(underlyingQueue))
        
        createSessionIfNeeded()

        var task = tasks[request.url]
        if task == nil {
            // 每个下载任务先下载到临时文件路径，完成后再 copy 到指定的路径
            task = DownloadTask(url: request.url,
                                headers: request.headers,
                                tmpFilePath: tmpFilePath,
                                timeoutInterval: request.timeoutInterval,
                                priority: request.priority,
                                networkServiceType: request.networkServiceType)
            task?.manager = self
            tasks[request.url] = task
        }
        task?.start(with: session!, subscription: subscription)
    }
    
    
    private func fetchTask(with sessionTask: URLSessionTask) -> DownloadTask? {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        if let url = sessionTask.originalRequest?.url,
           let task = tasks[url] {
            return task
        } else if let taskDescription = sessionTask.taskDescription,
                  let url = URL(string: taskDescription),
                  let task = tasks[url] {
            return task
        } else {
            return nil
        }
    }
    
    func cancel(token: DownloadTaskCancelToken) {
        underlyingQueue.async {
            let task = self.tasks[token.url]
            task?.cancel(key: token.key)
        }
    }
    
    func didCancelTask(_ task: DownloadTask) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        tasks[task.url] = nil
    }
}

extension FileDownloader {
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        logger.log(.error, message: "session become invalidation")
        
        self.session = nil
        createSessionIfNeeded()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        guard let task = fetchTask(with: dataTask) else {
            logger.log(.error, message: "cannot fetch download task in urlSession(_:dataTask:didReceive:completionHandler:) method, url: \(dataTask.originalRequest?.url?.absoluteString ?? "")")
            return
        }
        task.didReceive(response: response, completionHandler: completionHandler)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        protectedState.challengeHandler?(task, challenge, completionHandler) ?? completionHandler(.performDefaultHandling, nil)
    }
    
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let task = fetchTask(with: dataTask) else {
            logger.log(.error, message:"cannot fetch download task in urlSession(_:dataTask:didReceive:) method, url: \(dataTask.originalRequest?.url?.absoluteString ?? "")")
            return
        }
        task.didReceive(dataTask: dataTask, data: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = fetchTask(with: task) else {
            logger.log(.error, message: "cannot fetch download task in urlSession(_:task:didCompleteWithError:) method, url: \(task.originalRequest?.url?.absoluteString ?? "")")
            return
        }
        downloadTask.didComplete(task: task, error: error)
    }
}
