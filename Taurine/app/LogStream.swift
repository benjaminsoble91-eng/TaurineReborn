//
//  LogStream.swift
//  Odyssey
//
//  Created by CoolStar on 7/1/20.
//  Copyright © 2020 coolstar. All rights reserved.
//
//  Taurine Reborn: rewritten for speed and thread safety.
//   - One serial read queue (the original used a *concurrent* queue, so stdout and
//     stderr could append to the same NSMutableAttributedString at the same time).
//   - Read buffers are allocated once instead of on every read event.
//   - UI reload notifications are coalesced (~15/sec max) instead of one per chunk,
//     so the main thread isn't re-rendering the whole log while the jailbreak runs.
//   - Text attributes (colour + monospaced font) are built once, so the log view
//     never has to re-style the entire log.
//   - The C entry points (logger_stdout / logger_stderr / swiftDebug_internal) and
//     pause()/resume() behave exactly as before.
//

import Foundation
import UIKit

final class StandardOutputStream: TextOutputStream {
    static let shared = StandardOutputStream()
    private let fileHandle = FileHandle(fileDescriptor: LogStream.shared.outputFd[1])
    func write(_ string: String) {
        fileHandle.write(Data(string.utf8))
    }
}

final class StandardErrorOutputStream: TextOutputStream {
    static let shared = StandardErrorOutputStream()
    private let fileHandle = FileHandle(fileDescriptor: LogStream.shared.errFd[1])
    func write(_ string: String) {
        fileHandle.write(Data(string.utf8))
    }
}

private var debugOutput = StandardOutputStream.shared
func debugPrint(items: Any...) {
    print(items, to: &debugOutput)
}

@_cdecl("swiftDebug_internal")
func swiftDebug(str: UnsafePointer<CChar>?){
    guard let str = str else {
        return
    }
    let swiftString = String(cString: str)
    debugPrint(swiftString)
}

@_cdecl("logger_stdout")
func logger_stdout() -> Int32 {
    LogStream.shared.outputFd[1]
}

@_cdecl("logger_stderr")
func logger_stderr() -> Int32 {
    LogStream.shared.errFd[1]
}

class LogStream {
    static let shared = LogStream()

    public let reloadNotification = Notification.Name("LogStreamReloadNotification")

    private(set) var outputFd: [Int32] = [0, 0]
    private(set) var errFd: [Int32] = [0, 0]

    private let readQueue = DispatchQueue(label: "org.coolstar.sileo.logstream", qos: .utility)

    private let outputSource: DispatchSourceRead
    private let errorSource: DispatchSourceRead

    // Guarded by `lock`.
    private let lock = NSLock()
    private let storage = NSMutableAttributedString()
    private var reloadScheduled = false

    /// Minimum gap between UI reloads. Keeps the main thread free during the jailbreak.
    private let reloadInterval: DispatchTimeInterval = .milliseconds(66)

    static let logFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private static let outAttributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: UIColor(white: 0.92, alpha: 1),
        .font: LogStream.logFont
    ]
    private static let errAttributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: UIColor(red: 1.0, green: 0.36, blue: 0.40, alpha: 1),
        .font: LogStream.logFont
    ]

    /// Full copy of the log (thread-safe).
    var outputString: NSAttributedString {
        lock.lock(); defer { lock.unlock() }
        return NSAttributedString(attributedString: storage)
    }

    /// Total length of the log in UTF-16 units (thread-safe).
    var length: Int {
        lock.lock(); defer { lock.unlock() }
        return storage.length
    }

    /// Everything appended since `offset` (thread-safe). Used by the log view to append incrementally.
    func text(since offset: Int) -> NSAttributedString? {
        lock.lock(); defer { lock.unlock() }
        guard offset < storage.length else { return nil }
        return storage.attributedSubstring(from: NSRange(location: offset, length: storage.length - offset))
    }

    init() {
        guard pipe(&outputFd) != -1,
            pipe(&errFd) != -1 else {
                fatalError("pipe failed")
        }

        let origOutput = dup(STDOUT_FILENO)
        let origErr = dup(STDERR_FILENO)

        setvbuf(stdout, nil, _IONBF, 0)

        guard dup2(outputFd[1], STDOUT_FILENO) >= 0,
            dup2(errFd[1], STDERR_FILENO) >= 0 else {
                fatalError("dup2 failed")
        }

        outputSource = DispatchSource.makeReadSource(fileDescriptor: outputFd[0], queue: readQueue)
        errorSource = DispatchSource.makeReadSource(fileDescriptor: errFd[0], queue: readQueue)

        let outFds = outputFd
        let errFds = errFd
        outputSource.setCancelHandler {
            close(outFds[0])
            close(outFds[1])
        }

        errorSource.setCancelHandler {
            close(errFds[0])
            close(errFds[1])
        }

        let bufsiz = Int(BUFSIZ) * 4
        // Both handlers run on the same serial queue, so one shared buffer is safe.
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)

        outputSource.setEventHandler { [unowned self] in
            self.drain(fd: self.outputFd[0], mirror: origOutput, buffer: buffer, size: bufsiz,
                       attributes: LogStream.outAttributes, source: self.outputSource)
        }

        errorSource.setEventHandler { [unowned self] in
            self.drain(fd: self.errFd[0], mirror: origErr, buffer: buffer, size: bufsiz,
                       attributes: LogStream.errAttributes, source: self.errorSource)
        }

        outputSource.resume()
        errorSource.resume()
    }

    private func drain(fd: Int32, mirror: Int32, buffer: UnsafeMutablePointer<UInt8>, size: Int,
                       attributes: [NSAttributedString.Key: Any], source: DispatchSourceRead) {
        let bytesRead = read(fd, buffer, size)
        guard bytesRead > 0 else {
            if bytesRead == -1 && errno == EAGAIN {
                return
            }
            source.cancel()
            return
        }
        write(mirror, buffer, bytesRead)

        let str = String(decoding: UnsafeBufferPointer(start: buffer, count: bytesRead), as: UTF8.self)
        let chunk = NSAttributedString(string: str, attributes: attributes)

        lock.lock()
        storage.append(chunk)
        let shouldSchedule = !reloadScheduled
        reloadScheduled = true
        lock.unlock()

        if shouldSchedule {
            DispatchQueue.main.asyncAfter(deadline: .now() + reloadInterval) { [weak self] in
                guard let self = self else { return }
                self.lock.lock()
                self.reloadScheduled = false
                self.lock.unlock()
                NotificationCenter.default.post(name: self.reloadNotification, object: nil)
            }
        }
    }

    func pause(){
        outputSource.suspend()
        errorSource.suspend()
    }

    func resume(){
        outputSource.resume()
        errorSource.resume()
    }
}
