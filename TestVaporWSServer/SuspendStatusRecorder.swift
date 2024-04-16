//
//  SuspendStatusRecorder.swift
//  TestVaporWSServer
//
//  Created by Admin on 15/04/2024.
//

import Foundation
import UIKit
import Foundation

internal extension Notification.Name {
    static let applicationWillSuspend = Notification.Name("application-will-suspend")
    /// This notification gets called after the fact, but the `object` parameter is set to the `Date` of when the suspend occurred
    static let applicationDidSuspend = Notification.Name("application-did-suspend")
    static let applicationDidUnsuspend = Notification.Name("application-did-unsuspend")
    static let suspendStatusRecorderFailed = Notification.Name("suspend-status-recorder-failed")
}

internal class SuspendStatusRecorder {
    private var timer : Timer?
    private var task : UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid

    /// Start monitoring for suspend
    /// - parameter stallThreshold: Number of seconds of no processing before reporting a stall event
    internal func start() {
        stop() // If already going.
        startTask()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] (_) in
            self?.checkStatus()
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    internal func stop() {
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
        endTask()
    }

    private var lastPing : Int = 0
    private func willExpire() {
        endTask() // Allow app to suspend
        NotificationCenter.default.post(name: .applicationWillSuspend, object: nil)
        expectingSuspend = true
    }

    /// Set to an uptime value for when we expect our app to be suspended based on backgroundTimeRemaining
    private var expectingSuspend = false

    private func checkStatus() {
        let ping = uptime()
        if expectingSuspend {
            if ping - lastPing > 3 ||
            UIApplication.shared.applicationState == .active
            {
                // Timer stalled, either CPU failure or we were suspended.
                NotificationCenter.default.post(name: .applicationDidSuspend, object: Date(timeIntervalSinceNow: TimeInterval(lastPing - ping)))
                NotificationCenter.default.post(name: .applicationDidUnsuspend, object: nil)
                expectingSuspend = false
                startTask() // New background task so that we can make sure to catch next event
            }
        }
        lastPing = uptime()

        // In background, time is going to expire (resulting in suspend), report and end task
        if UIApplication.shared.applicationState == .background &&
           UIApplication.shared.backgroundTimeRemaining != Double.greatestFiniteMagnitude &&
           task != UIBackgroundTaskIdentifier.invalid
        {
            willExpire()
        }
    }

    private func endTask() {
        if task != UIBackgroundTaskIdentifier.invalid {
            UIApplication.shared.endBackgroundTask(task)
            self.task = UIBackgroundTaskIdentifier.invalid
        }
    }

    private func startTask() {
        task = UIApplication.shared.beginBackgroundTask(expirationHandler: { [weak self] in
            self?.willExpire()
        })
    }

    private func uptime() -> Int {
        var uptime = timespec()
        if 0 != clock_gettime(CLOCK_MONOTONIC_RAW, &uptime) {
            NotificationCenter.default.post(name: .suspendStatusRecorderFailed, object: "Could not execute clock_gettime, errno: \(errno)")
            stop()
        }
        return uptime.tv_sec
    }

    deinit {
        stop()
    }
}
