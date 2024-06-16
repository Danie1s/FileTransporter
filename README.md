

# FileTransporter

[![CI Status](https://img.shields.io/travis/liujunhua/FileTransporter.svg?style=flat)](https://travis-ci.org/liujunhua/FileTransporter)
[![Version](https://img.shields.io/cocoapods/v/FileTransporter.svg?style=flat)](https://cocoapods.org/pods/FileTransporter)
[![License](https://img.shields.io/cocoapods/l/FileTransporter.svg?style=flat)](https://cocoapods.org/pods/FileTransporter)
[![Platform](https://img.shields.io/cocoapods/p/FileTransporter.svg?style=flat)](https://cocoapods.org/pods/FileTransporter)

智品内部使用的文件加载（下载）库



## 特性

- 离线断点续传
- 线程安全
- 自定义保存路径，自定义文件名
- 处理认证质询
- 最大并发量
- 下载调度优先级
- 文件校验
- Log
- Network Monitor



## 环境要求

- iOS 10.0+
- Xcode 11.0+
- Swift 5.0+



## Installation

FileTransporter is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'FileTransporter'
```



## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.



## 用法

### 基本用法

传入 url，如果有缓存，则直接返回对应的文件本地地址，否则从网络中下载文件后返回

```swift
// 初始化，需要对它进行持有，否则当前代码块结束后会销毁
let fileTransporterManager = FileTransporterManager(identifier: "default")

let url = URL(string: "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg")!
let token = fileTransporterManager.loadFile(with: LoadRequest(url: url)) { progress in
    // 只有从网络下载时，才会调用此闭包                                                                      
    print("下载进度: \(String(format: "%.2f", progress.fractionCompleted * 100))%")
} completion: { result in
    switch result {
    case let .success(response):
        print("成功，destination: \(response.destination)，是否缓存: \(response.isCache)")
    case let .failure(error):
        switch error {
        case .cancel:
            print("取消")
        default:
            print("其他错误")
        }
    }
}

// 取消
token.cancel()
```



### 文件检验

如果是从网络下载，则只有文件校验正确才会成功；如果是有本地缓存，则不会再进行文件校验，直接成功

```swift
// 初始化，需要对它进行持有，否则当前代码块结束后会销毁
let fileTransporterManager = FileTransporterManager(identifier: "default")

// 当文件校验失败时调用，可以选择保留文件还是移除文件。默认不保留文件
// 注意，如果保留文件，则下次调用 loadFile 时，会直接成功
fileTransporterManager.vaildateFileErrorHandler = { (url, filePath) in
    return true
}

let url = URL(string: "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg")!
let token = fileTransporterManager.loadFile(
    with: LoadRequest(url: url,
                      verificationType: .md5(code: "9e2a3650530b563da297c9246acaad5c"))
) { progress in
    // 只有网络下载时，才会调用此闭包
    print("下载进度: \(String(format: "%.2f", progress.fractionCompleted * 100))%")
} completion: { result in

    switch result {
    case let .success(response):
        // 如果是从网络下载，则只有文件校验正确，才会成功；如果是有本地缓存，则不会再进行文件校验，直接成功
        print("成功，destination: \(response.destination)，是否缓存: \(response.isCache)")
    case let .failure(error):
        switch error {
        case .cancel:
            print("取消")
        case .fileVerificationError:
            print("文件校验： 错误")
        default:
            print("其他错误")
        }
    }
}

```



### 处理认证质询

```swift
let downloader = FileDownloader(identifier: "default")
downloader.challengeHandler = { task, challenge, completionHandler in
    completionHandler(.performDefaultHandling, nil)
}
let fileTransporterManager = FileTransporterManager(identifier: "default")
```



### 移除缓存

FileTransporter 内部对是否存在缓存的判断进行了优化，所以如果需要移除某个文件，则需要使用 Cache 进行

```swift
let fileTransporterManager = FileTransporterManager(identifier: "default")

let url = URL(string: "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg")!
fileTransporterManager.cache.removeFile(url: url)
```



### Network Monitor

在 FileDownloader 初始化时，可以提供一个遵守 NetworkMonitor 协议的对象，从而监听文件下载时的网络信息



### Log

FileTransporter 内部提供了一个遵守 Logable 协议的 Logger 类型，用于把重要的流程（错误）信息打印出来。开发者可以继承 Logger 改变它的默认行为，也可以自定义一个新的遵守 Logable 协议的类型。



### 特殊用法

每个 FileTransporterManager 支持设置最大并发数，想要对不同类型任务进行下载的管理，可以创建不同的 FileTransporterManager，它们可以共享同一个 FileDownloader，Cache，从而避免重复下载

```swift
let logger = Logger(identifier: "common", level: .none)
let rootQueue = DispatchQueue(label: "com.FileTransporterManager.root")
let cache = Cache(identifier: "common")
let downloader = FileDownloader(identifier: "common",
                                tmpFileDirectoryPath: cache.tmpFileDirectoryPath,
                                underlyingQueue: rootQueue,
                                logger: logger)

// 如果要共用一个 download、cache，那么必须共用一个 rootQueue
let logger1 = Logger(identifier: "default", level: .none)
defaultManager = FileTransporterManager(identifier: "default",
                                        logger: logger1,
                                        downloader: downloader,
                                        cache: cache,
                                        rootQueue: rootQueue)


let logger2 = Logger(identifier: "background", level: .none)
backgroundManager = FileTransporterManager(identifier: "background",
                                           maxConcurrentTasksLimit: 1,
                                           logger: logger2,
                                           downloader: downloader,
                                           cache: cache,
                                           rootQueue: rootQueue)
```



## Author

liujunhua, ljh_zhipin@qq.com

## License

FileTransporter is available under the MIT license. See the LICENSE file for more info.
