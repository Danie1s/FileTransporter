//
//  ViewController4.swift
//  Kingfisher
//
//  Created by daniels on 2024/5/31.
//
//  Copyright (c) 2024 Wei Wang <onevcat@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit
import FileTransporter

class ViewController4: UIViewController {
    
    
    let manager: FileTransporterManager = {
        let rootQueue = DispatchQueue(label: "ViewController4")
        let cache = Cache(identifier: "ViewController4")
        let downloader = FileDownloader(identifier: "ViewController1", tmpFileDirectoryPath: cache.tmpFileDirectoryPath, underlyingQueue: rootQueue)
        return FileTransporterManager(identifier: "ViewController1", downloader: downloader, cache: cache, rootQueue: rootQueue)
    }()

    var urls: [URL]!
    
    var tokens: [LoadTaskCancelToken] = []
    
    var lock = NSLock()
    
    var queues: [DispatchQueue]  = [.main, DispatchQueue(label: "1"), DispatchQueue(label: "2"), DispatchQueue(label: "3")]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let URLStrings = NSArray(contentsOfFile: Bundle.main.path(forResource: "VideoURLStrings.plist", ofType: nil)!) as! [String]

        urls = URLStrings.compactMap { URL(string: $0) }

    }
    
    @IBAction func start(_ sender: Any) {
        urls.forEach { url in
            let index = Int.random(in: queues.indices)
            let queue = queues[index]
            queue.async {
                let queue = DispatchQueue(label: "callback")
                let token = self.manager.loadFile(with: LoadRequest(url: url), queue: queue, completion: { reuslt in
                    dispatchPrecondition(condition: .onQueue(queue))
                    switch reuslt {
                    case .success:
                        break
                    case let .failure(error):
                        if case .cancel = error {
                        } else {
                            print("testtest \(error)")
                        }
                    }
                })
                self.lock.lock()
                self.tokens.append(token)
                self.lock.unlock()
            }
        }

    }
    
    @IBAction func cancel(_ sender: Any) {
        tokens.forEach { token in
            let index = Int.random(in: queues.indices)
            let queue = queues[index]
            queue.async {
                token.cancel()
            }
        }
        
    }
}
