//
//  DownloadRequest.swift
//  FileTransporter
//
//  Created by 刘俊华 on 2023/3/20.
//

import Foundation

public struct DownloadRequest {
    
    public let url: URL
    
    public let headers: [String: String]?
    
    public let destination: String
        
    public let timeoutInterval: TimeInterval
    
    // 0.0 ~ 1.0
    public let priority: Float
    
    public let networkServiceType: URLRequest.NetworkServiceType
        
    public init(url: URL,
                headers: [String: String]? = nil,
                destination: String,
                timeoutInterval: TimeInterval = 60,
                priority: Float = URLSessionTask.defaultPriority,
                networkServiceType: URLRequest.NetworkServiceType = .default) {
        self.url = url
        self.headers = headers
        self.destination = destination
        self.timeoutInterval = timeoutInterval
        self.priority = priority
        self.networkServiceType = networkServiceType
    }
}
