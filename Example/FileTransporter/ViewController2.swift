//
//  ViewController2.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import FileTransporter

class ViewController2: BaseViewController {

    override func viewDidLoad() {
        
        fileTransporterManager = FileTransporterManager(identifier: "ViewController2", maxConcurrentTasksLimit: 1)

        super.viewDidLoad()


        let URLStrings = [
            "https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Office_16.24.19041401_Installer.pkg",
            "https://sf3-cn.feishucdn.com/obj/ee-appcenter/746ebb24/Feishu-darwin_arm64-5.32.6-signed.dmg",
            "http://dldir1.qq.com/qqfile/QQforMac/QQ_V6.5.2.dmg",
            "http://issuecdn.baidupcs.com/issue/netdisk/MACguanjia/BaiduNetdisk_mac_2.2.3.dmg",
            "https://qd.myapp.com/myapp/qqteam/pcqq/QQ9.0.8_2.exe",
            "https://dldir1.qq.com/qqtv/mac/TencentVideo2.65.0.53560.dmg",
            "https://static-d.iqiyi.com/ext/common/iQIYIMedia_271.dmg",
            "https://pcclient.download.youku.com/iku_electron_client/youkuclient_setup_9.2.15.1002.dmg?spm=a2hcb.25507605.product.1&file=youkuclient_setup_9.2.15.1002.dmg",
            "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg"
        ]
        
        urls = URLStrings.compactMap { URL(string: $0) }

        setupManager()

        updateUI()
        tableView.reloadData()
        
    }
}


// MARK: - tap event
extension ViewController2 {

    @IBAction func addDownloadTask(_ sender: Any) {
        guard let url = urls.first(where: { url in
            !downloadItems.contains(where: { $0.url == url })
        }) else { return }
        
        let item = DownloadItem(url: url, fileName: Cache.fileName(url: url))
        downloadItems.append(item)
        startDownload(item: item)
        tableView.reloadData()

    }

    @IBAction func deleteDownloadTask(_ sender: UIButton) {
        let count = downloadItems.count
        guard count > 0 else { return }
        let index = count - 1
        let item = downloadItems.remove(at: index)
        item.cell?.item = nil
        item.token?.cancel()
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
    }
    
    
    @IBAction func sort(_ sender: Any) {

    }
}



