//
//  FileTransporterError.swift
//  FileTransporter
//
//  Created by Daniels on 2019/5/14.
//  Copyright © 2019 Daniels. All rights reserved.
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
//

import Foundation

public enum FileTransporterError: Error {
        
    public enum CacheErrorReason {
        case cannotCreateDirectory(path: String, error: Error)
        case cannotRemoveItem(path: String, error: Error)
        case cannotMoveItem(atPath: String, toPath: String, error: Error)
        case cannotRetrieveAllTasks(path: String, error: Error)
        case cannotEncodeTasks(path: String, error: Error)
        case fileDoesnotExist(path: String)
        case readDataFailed(path: String)
    }
    
    public enum DownloadError {
        case invalidURLResponse(response: URLResponse)
        case unacceptableStatusCode(Int)
        case underlying(error: Error)
        case cannotCopyItem(atPath: String, toPath: String, statusCode: Int, error: Error)
    }
    
    public enum FileVerificationError: Error {
        case codeMismatch(code: String)
        case readDataFailed(path: String)
    }
    
    case unknown
    case cancel
    case subscriptionEmpty
    case downloadError(DownloadError)
    case cacheError(reason: CacheErrorReason)
    case fileVerificationError(FileVerificationError)
    
    public var underlyingError: Error? {
        switch self {
        case let .downloadError(error):
            return error.underlyingError
        case let .cacheError(reason: reason):
            return reason.underlyingError
        default:
            return nil
        }
    }
    
    public var urlError: URLError? {
        underlyingError as? URLError
    }
}

extension FileTransporterError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unknown:
            return "unkown error"
        case .cancel:
            return "cancel"
        case .subscriptionEmpty:
            return "subscription Empty"
        case let .downloadError(downloadError):
            return "download error \(downloadError.errorDescription ?? "")"
        case let .cacheError(reason):
            return "cache error: \(reason.errorDescription ?? "")"
        case let .fileVerificationError(error):
            return "file verification error: \(error.errorDescription ?? "")"
        }
    }
}

extension FileTransporterError: CustomNSError {
    
    public static let errorDomain: String = "com.Daniels.FileTransporter.Error"

    public var errorCode: Int {
        return -1
    }

    public var errorUserInfo: [String: Any] {
        if let errorDescription = errorDescription {
            return [NSLocalizedDescriptionKey: errorDescription]
        } else {
            return [String: Any]()
        }
        
    }
}

extension FileTransporterError.CacheErrorReason {
    
    public var errorDescription: String? {
        switch self {
        case let .cannotCreateDirectory(path, error):
            return "can not create directory, path: \(path), underlying: \(error)"
        case let .cannotRemoveItem(path, error):
            return "can not remove item, path: \(path), underlying: \(error)"
        case let .cannotMoveItem(atPath, toPath, error):
            return "can not move item atPath: \(atPath), toPath: \(toPath), underlying: \(error)"
        case let .cannotRetrieveAllTasks(path, error):
            return "can not retrieve all tasks, path: \(path), underlying: \(error)"
        case let .cannotEncodeTasks(path, error):
            return "can not encode tasks, path: \(path), underlying: \(error)"
        case let .fileDoesnotExist(path):
            return "file does not exist, path: \(path)"
        case let .readDataFailed(path):
            return "read data failed, path: \(path)"
        }
    }

    public var underlyingError: Error? {
        switch self {
        case let .cannotCreateDirectory(_, error):
            return error
        case let .cannotRemoveItem(_, error):
            return error
        case let .cannotMoveItem(_, _, error):
            return error
        case let .cannotRetrieveAllTasks(_, error):
            return error
        case let .cannotEncodeTasks(_, error):
            return error
        default:
            return nil
        }
    }
}


extension FileTransporterError.DownloadError {
    
    public var errorDescription: String? {
        switch self {
        case let .invalidURLResponse(response):
            return "invalid URLResponse: \(response)"
        case let .unacceptableStatusCode(code):
            return "unacceptable status code: \(code)"
        case let .underlying(error):
            return "download failed, error: \(error)"
        case .cannotCopyItem(atPath: let atPath, toPath: let toPath, statusCode: let statusCode, error: let error):
            return "can not copy item, atPath: \(atPath), toPath: \(toPath), status code: \(statusCode), underlying: \(error)"
        }
    }

    public var underlyingError: Error? {
        switch self {
        case let .underlying(error):
            return error
        default:
            return nil
        }
    }
}

extension FileTransporterError.FileVerificationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .codeMismatch(code):
            return "verification code mismatch, code: \(code)"
        case let .readDataFailed(path):
            return "read data failed, path: \(path)"
        }
    }

    public var underlyingError: Error? {
        return nil
    }
}
