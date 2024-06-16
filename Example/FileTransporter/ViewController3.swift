//
//  ViewController3.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import FileTransporter

class ViewController3: BaseViewController {


    override func viewDidLoad() {
        
        fileTransporterManager = FileTransporterManager(identifier: "ViewController3")

        super.viewDidLoad()
        

        let URLStrings = (NSArray(contentsOfFile: Bundle.main.path(forResource: "VideoURLStrings.plist", ofType: nil)!) as! [String])

        urls = URLStrings.compactMap { URL(string: $0) }


        setupManager()

        fileTransporterManager.logger.level = .none

        updateUI()
        tableView.reloadData()
    }
}


// MARK: - tap event
extension ViewController3 {


    @IBAction func multiDownload(_ sender: Any) {
        guard downloadItems.count < urls.count else { return }
        
        downloadItems = urls.map {
            DownloadItem(url: $0, fileName: Cache.fileName(url: $0))
        }
        
        let begin = CFAbsoluteTimeGetCurrent()
        // 如果任务数量过多，可以在子线程开启
        downloadItems.forEach {
            startDownload(item: $0, shouldUpdateUI: false)
        }
     
        
        updateUI()
        
        print("cost time: \(CFAbsoluteTimeGetCurrent() - begin)")
        tableView.reloadData()
        
    }
}

