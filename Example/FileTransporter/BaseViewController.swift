//
//  BaseViewController.swift
//  Example
//
//  Created by Daniels on 2018/3/20.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import FileTransporter

class DownloadItem {
    
    enum Status {
        case initial
        case running
        case cancel
        case succeeded
        case failed
    }
    
    let url: URL
    
    let fileName: String
    
    var token: LoadTaskCancelToken?
        
    var status: Status = .initial
    
    let progress: Progress = Progress()
    
    var isCache: Bool?
    
    weak var cell: DownloadTaskCell?
    
    init(url: URL, fileName: String) {
        self.url = url
        self.fileName = fileName
    }
    
    func update() {
        cell?.item = self
    }

}

class BaseViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var totalTasksLabel: UILabel!
    @IBOutlet weak var totalSpeedLabel: UILabel!
    @IBOutlet weak var timeRemainingLabel: UILabel!
    @IBOutlet weak var totalProgressLabel: UILabel!
    
    
    @IBOutlet weak var taskLimitSwitch: UISwitch!
    @IBOutlet weak var cellularAccessSwitch: UISwitch!
    
    
    var fileTransporterManager: FileTransporterManager!
    
    var urls: [URL] = []
    
    var downloadItems: [DownloadItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        // 检查磁盘空间
        let free = FileManager.default.ft.freeDiskSpaceInBytes / 1024 / 1024
        print("手机剩余储存空间为： \(free)MB")
        
        fileTransporterManager.logger.level = .default
        
        updateSwicth()
    }
    
    func setupUI() {
        // tableView的设置
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.register(UINib(nibName: "\(DownloadTaskCell.self)", bundle: nil),
                           forCellReuseIdentifier: DownloadTaskCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 164
        
        configureNavigationItem()
    }
    
    func configureNavigationItem() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "编辑",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(toggleEditing))
    }
    
    
    @objc func toggleEditing() {
        tableView.setEditing(!tableView.isEditing, animated: true)
        let button = navigationItem.rightBarButtonItem!
        button.title = tableView.isEditing ? "完成" : "编辑"
    }
    
    func updateUI() {
        let succeddCount = downloadItems.filter({ $0.status == .succeeded })
        totalTasksLabel.text = "总任务：\(succeddCount.count)/\(downloadItems.count)"
//        totalSpeedLabel.text = "总速度：\(sessionManager.speedString)"
//        timeRemainingLabel.text = "剩余时间： \(sessionManager.timeRemainingString)"
//        let per = String(format: "%.2f", sessionManager.progress.fractionCompleted)
//        totalProgressLabel.text = "总进度： \(per)"
    }
    
    func updateSwicth() {
//        taskLimitSwitch.isOn = sessionManager.configuration.maxConcurrentTasksLimit < 3
//        cellularAccessSwitch.isOn = sessionManager.configuration.allowsCellularAccess
    }
    
    func setupManager() {
        

    }
    
    func startDownload(item: DownloadItem, shouldUpdateUI: Bool = true) {
        item.token?.cancel()
        item.status = .initial
        item.token = fileTransporterManager.loadFile(with: LoadRequest(url: item.url), progress: { [weak item] progress in
            item?.progress.totalUnitCount = progress.totalUnitCount
            item?.progress.completedUnitCount = progress.completedUnitCount
            item?.status = .running
            item?.update()
        }, completion: { [weak self, weak item] result in
            switch result {
            case .success:
                item?.status = .succeeded
            case let .failure(error):
                if case .cancel = error {
                    item?.status = .cancel
                } else {
                    item?.status = .failed
                }
                
            }
            item?.update()
            self?.updateUI()
        })
        item.update()
        if shouldUpdateUI {
            updateUI()
        }
        
    }
    
}

extension BaseViewController {
    @IBAction func totalStart(_ sender: Any) {
        downloadItems.forEach { item in
            if item.status != .running {
                startDownload(item: item)
            }
        }
    }
    
    
    @IBAction func totalCancel(_ sender: Any) {
        downloadItems.forEach { item in
            item.token?.cancel()
        }
        tableView.reloadData()
    }
    
    @IBAction func totalDelete(_ sender: Any) {
        downloadItems.forEach { item in
            item.token?.cancel()
        }
        downloadItems.removeAll()
        tableView.reloadData()
    }
    
    @IBAction func clearDisk(_ sender: Any) {
        fileTransporterManager.cache.clearDiskCache()

    }
    
    
    @IBAction func taskLimit(_ sender: UISwitch) {
        if sender.isOn {
            fileTransporterManager.maxConcurrentTasksLimit = 1
        } else {
            fileTransporterManager.maxConcurrentTasksLimit = Int.max
        }
    }
    
    @IBAction func cellularAccess(_ sender: UISwitch) {
//        sessionManager.configuration.allowsCellularAccess = sender.isOn
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension BaseViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DownloadTaskCell.reuseIdentifier, for: indexPath) as! DownloadTaskCell
        let item = downloadItems[indexPath.row]
        cell.item = item
        cell.tapClosure = { [weak self] cell in
            guard let self = self else { return }
            if cell.item?.status == .running || cell.item?.status == .initial {
                cell.item?.token?.cancel()
            } else if cell.item?.status == .cancel || cell.item?.status == .failed {
                // 开启下载任务
                if let item = cell.item {
                    self.startDownload(item: item)
                }
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? DownloadTaskCell else { return }
        let item = downloadItems[indexPath.row]
        cell.item = item
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? DownloadTaskCell else { return }
        cell.item = nil
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let item = downloadItems.remove(at: indexPath.row)
            item.token?.cancel()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let item = downloadItems.remove(at: sourceIndexPath.row)
        downloadItems.insert(item, at: destinationIndexPath.row)
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}
