//
//  ViewController.swift
//  FileTransporter
//
//  Created by liujunhua on 03/02/2023.
//  Copyright (c) 2023 liujunhua. All rights reserved.
//

import UIKit
import FileTransporter

class ViewController: UIViewController {

    @IBOutlet weak var backgroundTasksLabel: UILabel!
    @IBOutlet weak var backgroundCacheTasksLabel: UILabel!
    @IBOutlet weak var backgroundDownloadTasksLabel: UILabel!
    @IBOutlet weak var backgroundDownloadFailLabel: UILabel!
    
    
    @IBOutlet weak var tasksLabel: UILabel!
    @IBOutlet weak var cacheTasksLabel: UILabel!
    @IBOutlet weak var downloadTasksLabel: UILabel!
    @IBOutlet weak var downloadFailLabel: UILabel!

    var defaultManager: FileTransporterManager!
    
    var backgroundManager: FileTransporterManager!
    
    var urls: [URL]!
    
    var backgroundDownloadItems: [DownloadItem] = []

    var downloadItems: [DownloadItem] = []

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        let URLStrings = NSArray(contentsOfFile: Bundle.main.path(forResource: "gifts.plist", ofType: nil)!) as! [String]
        let URLStrings = NSArray(contentsOfFile: Bundle.main.path(forResource: "VideoURLStrings.plist", ofType: nil)!) as! [String]

        urls = URLStrings.compactMap { URL(string: $0) }
        
        
        let logger = Logger(identifier: "common", level: .error)
        let rootQueue = DispatchQueue(label: "root")
        let cache = Cache(identifier: "common")
        let downloader = FileDownloader(identifier: "common", tmpFileDirectoryPath: cache.tmpFileDirectoryPath, underlyingQueue: rootQueue, logger: logger)
        
        // 如果要共用一个 download、cache，那么必须共用一个 rootQueue
        let logger1 = Logger(identifier: "default", level: .error)
        defaultManager = FileTransporterManager(identifier: "default", logger: logger1, downloader: downloader, cache: cache, rootQueue: rootQueue)
        
        
        let logger2 = Logger(identifier: "background", level: .error)
        backgroundManager = FileTransporterManager(identifier: "background", maxConcurrentTasksLimit: 1, logger: logger2, downloader: downloader, cache: cache, rootQueue: rootQueue)
        

        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateUI()

    }
    
    func updateUI() {
        let backgroundSucceededTasks = backgroundDownloadItems.filter({ $0.status == .succeeded })
        backgroundTasksLabel.text = "总任务：\(backgroundSucceededTasks.count)/\(backgroundDownloadItems.count)"
        backgroundCacheTasksLabel.text = "磁盘缓存：\(backgroundSucceededTasks.filter { $0.isCache != nil && $0.isCache == true }.count)"
        backgroundDownloadTasksLabel.text = "下载成功：\(backgroundSucceededTasks.filter { $0.isCache != nil && $0.isCache == false }.count)"
        backgroundDownloadFailLabel.text = "下载失败：\(backgroundDownloadItems.filter({ $0.status == .failed }).count)"

        let succeededTasks = downloadItems.filter({ $0.status == .succeeded })
        tasksLabel.text = "总任务：\(succeededTasks.count)/\(downloadItems.count)"
        cacheTasksLabel.text = "磁盘缓存：\(succeededTasks.filter { $0.isCache != nil && $0.isCache == true }.count)"
        downloadTasksLabel.text = "下载成功：\(succeededTasks.filter { $0.isCache != nil && $0.isCache == false }.count)"
        downloadFailLabel.text = "下载失败：\(downloadItems.filter({ $0.status == .failed }).count)"

    }

    @IBAction func backgroundStart(_ sender: Any) {

        backgroundDownloadItems = urls.map {
            DownloadItem(url: $0, fileName: Cache.fileName(url: $0))
        }
        
        backgroundDownloadItems.forEach { item in
            item.token?.cancel()
            item.status = .initial
            item.token = backgroundManager.loadFile(with: LoadRequest(url: item.url), progress: { [weak item] progress in
                item?.status = .running
            }, completion: { [weak self, weak item] result in
                switch result {
                case let .success(response):
                    item?.status = .succeeded
                    item?.isCache = response.isCache
                case let .failure(error):
                    if case .cancel = error {
                        item?.status = .cancel
                    } else {
                        item?.status = .failed
                    }
                    
                }
                self?.updateUI()
            })
        }
        updateUI()
    }
    
    @IBAction func backgroundCancel(_ sender: Any) {
        backgroundDownloadItems.forEach { item in
            item.token?.cancel()
        }
        backgroundDownloadItems.removeAll()
        updateUI()
    }
    
    
    @IBAction func clear(_ sender: Any) {
        backgroundManager.cache.clearDiskCache()

    }
    
    
    @IBAction func start(_ sender: Any) {
        
        downloadItems = urls.map {
            DownloadItem(url: $0, fileName: Cache.fileName(url: $0))
        }
        
        downloadItems.forEach { item in
            item.token?.cancel()
            item.status = .initial
            item.token = defaultManager.loadFile(with: LoadRequest(url: item.url), progress: { [weak item] progress in
                item?.status = .running
            }, completion: { [weak self, weak item] result in
                switch result {
                case let .success(response):
                    item?.status = .succeeded
                    item?.isCache = response.isCache
                case let .failure(error):
                    if case .cancel = error {
                        item?.status = .cancel
                    } else {
                        item?.status = .failed
                    }
                    
                }
                self?.updateUI()
            })
        }
        updateUI()
    }
    
    
    @IBAction func cancel(_ sender: Any) {
        downloadItems.forEach { item in
            item.token?.cancel()
        }
        downloadItems.removeAll()
        updateUI()
    }
}

