//
//  ViewController1.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import FileTransporter

class ViewController1: UIViewController {

    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressView2: UIProgressView!
    @IBOutlet weak var timeRemainingLabel: UILabel!
    @IBOutlet weak var startDateLabel: UILabel!
    @IBOutlet weak var endDateLabel: UILabel!
    @IBOutlet weak var validationLabel: UILabel!
    
    
    lazy var cache = Cache(identifier: "ViewController1")
    
    let rootQueue = DispatchQueue(label: "ViewController1")
    
    lazy var downloader = FileDownloader(identifier: "ViewController1", tmpFileDirectoryPath: cache.tmpFileDirectoryPath, underlyingQueue: rootQueue)

    lazy var fileTransporterManager = FileTransporterManager(identifier: "ViewController1", downloader: downloader, cache: cache, rootQueue: rootQueue)
    
    // 如果要共用一个 download、cache，那么必须共用一个 rootQueue
    lazy var _fileTransporterManager2 = FileTransporterManager(identifier: "ViewController1 - 2", downloader: downloader, cache: cache, rootQueue: rootQueue)
    
    lazy var fileTransporterManager2 = fileTransporterManager

    var token: LoadTaskCancelToken?
    
    var token2: LoadTaskCancelToken?
    
//    lazy var url = URL(string: "https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/OfficeMac/Microsoft_Office_2016_16.10.18021001_Installer.pkg")!
    
    lazy var url = URL(string: "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg")!

    
//    lazy var url = URL(string: "https://sf3-cn.feishucdn.com/obj/ee-appcenter/746ebb24/Feishu-darwin_arm64-5.32.6-signed.dmg")!

    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*
         测试内容:
         同一个 FileTransporterManager 复用同一个 LoadRequest，不会创建两个 LoadTask，不会创建两个 DownloadTask
         不同 FileTransporterManager 复用同一个 downloader， cache， LoadRequest，创建两个 LoadTask，不会创建两个 DownloadTask
         */
         
        
    }

    
    @IBAction func start(_ sender: UIButton) {
        token?.cancel()
        token = fileTransporterManager.loadFile(
            with: LoadRequest(url: url,
                              verificationType: .md5(code: "9e2a3650530b563da297c9246acaad5c"))
        ) { [weak self] progress in
            guard let self = self else { return }
            let per = progress.fractionCompleted
            self.progressLabel.text = "progress： \(String(format: "%.2f", per * 100))%"
            self.progressView.observedProgress = progress
        } completion: { [weak self] result in
            guard let self = self else { return }
            self.progressView.observedProgress = nil
            switch result {
            case .success:
                self.validationLabel.textColor = UIColor.green
                self.validationLabel.text = "文件验证： 正确"
            case let .failure(error):
                if case .fileVerificationError = error {
                    self.validationLabel.textColor = UIColor.red
                    self.validationLabel.text = "文件验证： 错误"
                } else {
                    self.validationLabel.textColor = UIColor.blue
                    self.validationLabel.text = "文件验证： 未知"
                }
            }
        }


    }


    @IBAction func cancel(_ sender: UIButton) {
        token?.cancel()
    }


    @IBAction func clearDisk(_ sender: Any) {
        fileTransporterManager.cache.clearDiskCache()
    }
    
    
    @IBAction func start2(_ sender: Any) {
        fileTransporterManager2 = fileTransporterManager
        startTask2()
    }
    
    @IBAction func changeManager(_ sender: Any) {
        fileTransporterManager2 = _fileTransporterManager2
        startTask2()
    }
    
    private func startTask2() {
        token2?.cancel()
        token2 = fileTransporterManager2.loadFile(
            with: LoadRequest(url: url,
                              fileName: Cache.fileName(url: url) + "1",
                              verificationType: .md5(code: "9e2a3650530b563da297c9246acaad5c"))
        ) { [weak self] progress in
            guard let self = self else { return }
            self.progressView2.observedProgress = progress
        } completion: { [weak self] _ in
            self?.progressView2.observedProgress = nil
        }
    }
    
    @IBAction func cancel2(_ sender: Any) {
        token2?.cancel()
    }
}

