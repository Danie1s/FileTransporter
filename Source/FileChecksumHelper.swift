//
//  FileChecksumHelper.swift
//  FileTransporter
//
//  Created by Daniels on 2019/1/22.
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
import CommonCrypto

public enum VerificationType: Hashable, CustomStringConvertible {
    case md5(code: String)
    case sha1(code: String)
    case sha256(code: String)
    case sha512(code: String)
    
    public var description: String {
        switch self {
        case let .md5(code):
            return "md5: \(code)"
        case let .sha1(code):
            return "sha1: \(code)"
        case let .sha256(code):
            return "sha256: \(code)"
        case let .sha512(code):
            return "sha512: \(code)"
        }
    }
}


public enum FileChecksumHelper {
    
    private static let ioQueue = DispatchQueue(label: "com.FileChecksumHelper.queue")
    
    public static func validateFile(_ filePath: String,
                                    type: VerificationType,
                                    queue: DispatchQueue,
                                    completion: @escaping (Result<Void, FileTransporterError>) -> ()) {
        ioQueue.async {
            let url = URL(fileURLWithPath: filePath)

            do {
                let file = try FileHandle(forReadingFrom: url)
                defer {
                    file.closeFile()
                }
                
                let string: String
                let verificationCode: String
                switch type {
                case let .md5(code):
                    verificationCode = code
                    string = md5(for: file)
                case let .sha1(code):
                    verificationCode = code
                    string = sha1(for: file)
                case let .sha256(code):
                    verificationCode = code
                    string = sha256(for: file)
                case let .sha512(code):
                    verificationCode = code
                    string = sha512(for: file)
                }
                let isCorrect = string.lowercased() == verificationCode.lowercased()
                if isCorrect {
                    queue.async {
                        completion(.success(()))
                    }
                } else {
                    queue.async {
                        completion(.failure(.fileVerificationError(.codeMismatch(code: string))))
                    }
                }
            } catch {
                queue.async {
                    completion(.failure(.fileVerificationError(.readDataFailed(path: filePath))))
                }
            }
        }
    }
    
    private static func md5(for file: FileHandle) -> String {

        let bufferSize = 1024 * 1024

        // Create and initialize MD5 context:
        var context = CC_MD5_CTX()
        CC_MD5_Init(&context)

        // Read up to `bufferSize` bytes, until EOF is reached, and update MD5 context:
        while autoreleasepool(invoking: {
            let data = file.readData(ofLength: bufferSize)
            if data.count > 0 {
                data.withUnsafeBytes {
                    _ = CC_MD5_Update(&context, $0.baseAddress, numericCast(data.count))
                }
                return true // Continue
            } else {
                return false // End of file
            }
        }) { }

        // Compute the MD5 digest:
        var digest: [UInt8] = Array(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = CC_MD5_Final(&digest, &context)
        
        let hexDigest = digest.map { String(format: "%02hhx", $0) }.joined()
        return hexDigest
    }
    
    
    private static func sha1(for file: FileHandle) -> String {
        
        let bufferSize = 1024 * 1024
        
        var context = CC_SHA1_CTX()
        CC_SHA1_Init(&context)

        while autoreleasepool(invoking: {
            let data = file.readData(ofLength: bufferSize)
            if data.count > 0 {
                data.withUnsafeBytes {
                    _ = CC_SHA1_Update(&context, $0.baseAddress, numericCast(data.count))
                }
                // Continue
                return true
            } else {
                // End of file
                return false
            }
        }) { }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1_Final(&digest, &context)

        let hexDigest = digest.map { String(format: "%02hhx", $0) }.joined()
        return hexDigest
    }

    
    private static func sha256(for file: FileHandle) -> String {
        
        let bufferSize = 1024 * 1024

        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)

        while autoreleasepool(invoking: {
            let data = file.readData(ofLength: bufferSize)
            if data.count > 0 {
                data.withUnsafeBytes {
                    _ = CC_SHA256_Update(&context, $0.baseAddress, numericCast(data.count))
                }
                return true
            } else {
                return false
            }
        }) { }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)
        
        let hexDigest = digest.map { String(format: "%02hhx", $0) }.joined()
        return hexDigest
    }
    
    
    private static func sha512(for file: FileHandle) -> String {
        
        let bufferSize = 1024 * 1024

        var context = CC_SHA512_CTX()
        CC_SHA512_Init(&context)

        while autoreleasepool(invoking: {
            let data = file.readData(ofLength: bufferSize)
            if data.count > 0 {
                data.withUnsafeBytes {
                    _ = CC_SHA512_Update(&context, $0.baseAddress, numericCast(data.count))
                }
                return true
            } else {
                return false
            }
        }) { }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        CC_SHA512_Final(&digest, &context)

        let hexDigest = digest.map { String(format: "%02hhx", $0) }.joined()
        return hexDigest
    }
}






