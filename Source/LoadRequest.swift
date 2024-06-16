//
//  LoadRequest.swift
//  FileTransporter
//
//  Created by 刘俊华 on 2023/3/6.
//

import Foundation

public struct LoadRequest {
    
    public let url: URL
    
    public let headers: [String: String]?

    // 自定义文件名
    public let fileName: String?
    
    // 超时时间
    public let timeoutInterval: TimeInterval
    
    public let verificationType: VerificationType?
        
    // 0.0 ~ 1.0
    public let priority: Float
    
    public let networkServiceType: URLRequest.NetworkServiceType
        
    public init(url: URL,
                headers: [String: String]? = nil,
                fileName: String? = nil,
                timeoutInterval: TimeInterval = 60,
                verificationType: VerificationType? = nil,
                priority: Float = URLSessionTask.defaultPriority,
                networkServiceType: URLRequest.NetworkServiceType = .default) {
        self.url = url
        self.headers = headers
        self.fileName = fileName
        self.timeoutInterval = timeoutInterval
        self.verificationType = verificationType
        self.priority = priority
        self.networkServiceType = networkServiceType
    }
    
}


extension LoadRequest: Hashable {
    public func hash(into hasher: inout Hasher) {
        var key: String = url.absoluteString
        if let fileName = fileName {
            key += fileName
        }
        if let verificationType = verificationType {
            key += "\(verificationType)"
        }
        hasher.combine(key)
    }

}
