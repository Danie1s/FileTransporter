//
//  DownloadTaskCell.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import FileTransporter

class DownloadTaskCell: UITableViewCell {
    
    static let reuseIdentifier = "reuseIdentifier"

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var bytesLabel: UILabel!
    @IBOutlet weak var controlButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var timeRemainingLabel: UILabel!
    @IBOutlet weak var startDateLabel: UILabel!
    @IBOutlet weak var endDateLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    var tapClosure: ((DownloadTaskCell) -> Void)?
    
    var item: DownloadItem? {
        didSet {
            oldValue?.cell = nil
            guard let item = item else { return }
            item.cell = self
            titleLabel.text = item.fileName
            let completedCount = ByteCountFormatter.string(fromByteCount: item.progress.completedUnitCount, countStyle: .file)
            let totalCount = ByteCountFormatter.string(fromByteCount: item.progress.totalUnitCount, countStyle: .file)
            progressView.progress = Float(item.progress.fractionCompleted)
            bytesLabel.text = "\(completedCount)/\(totalCount)"
            switch item.status {
            case .cancel:
                statusLabel.text = "暂停"
                statusLabel.textColor = .black
            case .running:
                statusLabel.text = "下载中"
                statusLabel.textColor = .blue
            case .succeeded:
                statusLabel.text = "成功"
                statusLabel.textColor = .green
            case .failed:
                statusLabel.text = "失败"
                statusLabel.textColor = .red
            case .initial:
                statusLabel.text = "等待中"
                statusLabel.textColor = .orange
            }
            
            if item.status == .running {
                controlButton.setImage(UIImage(named: "suspend"), for: .normal)
            } else {
                controlButton.setImage(UIImage(named: "resume"), for: .normal)
            }
        }
    }


    @IBAction func didTapButton(_ sender: Any) {
        tapClosure?(self)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
