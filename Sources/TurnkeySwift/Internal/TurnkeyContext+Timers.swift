import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

extension TurnkeyContext {
    
    /// Returns the system notification triggered when the app enters the foreground.
    ///
    /// Resolves the appropriate notification name based on the active platform (iOS, tvOS, visionOS, or macOS).
    ///
    /// - Returns: The platform-specific `Notification.Name` for foreground entry, or `nil` if unsupported.
    static var foregroundNotification: Notification.Name? {
        #if os(iOS) || os(tvOS) || os(visionOS)
            UIApplication.willEnterForegroundNotification
        #elseif os(macOS)
            NSApplication.didBecomeActiveNotification
        #else
            nil
        #endif
    }
    
    /// Reschedules expiry timers for all persisted sessions.
    ///
    /// Iterates through all stored sessions in the registry, restoring
    /// their expiration timers based on JWT expiry timestamps.
    ///
    /// - Note: This method is typically invoked during startup or after app resume.
    func rescheduleAllSessionExpiries() async {
        do {
            for key in try SessionRegistryStore.all() {
                guard let stored = try? JwtSessionStore.load(key: key) else { continue }
                scheduleExpiryTimer(for: key, expTimestamp: stored.decoded.exp)
            }
        } catch {
            // Silently fail
        }
    }
    
    /// Schedules an expiry timer for a given session.
    ///
    /// Sets up a timer that triggers just before a session’s JWT expiration time.
    /// If an auto-refresh duration is configured, the timer attempts to refresh the session.
    /// Otherwise, it clears the session when the timer fires.
    ///
    /// - Parameters:
    ///   - sessionKey: The key identifying the session to monitor.
    ///   - expTimestamp: The UNIX timestamp (in seconds) when the JWT expires.
    ///   - buffer: The number of seconds before expiry to trigger the timer early (default is 5 seconds).
    ///
    /// - Note: Existing timers for the same session are automatically cancelled before scheduling a new one.
    func scheduleExpiryTimer(
        for sessionKey: String,
        expTimestamp: TimeInterval,
        buffer: TimeInterval = 5
    ) {
        // cancel any old timer
        expiryTasks[sessionKey]?.cancel()
        
        let timeLeft = expTimestamp - Date().timeIntervalSince1970
        
        // if already within (or past) the buffer window, we just clear now
        if timeLeft <= buffer {
            clearSession(for: sessionKey)
            return
        }
        
        let interval = timeLeft - buffer
        let deadline = DispatchTime.now() + .milliseconds(Int(interval * 1_000))
        let timer = DispatchSource.makeTimerSource()
        
        timer.schedule(deadline: deadline, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            // we calculate how much time is left when this handler actually runs
            // this is needed because if the app was backgrounded past the expiry,
            // the dispatch timer will still fire once the app returns to foreground
            // this avoids making a call we know will fail
            let currentLeft = expTimestamp - Date().timeIntervalSince1970
            if currentLeft <= 0 {
                self.clearSession(for: sessionKey)
                timer.cancel()
                return
            }
            
            if let dur = AutoRefreshStore.durationSeconds(for: sessionKey) {
                Task {
                    do {
                        try await self.refreshSession(
                            expirationSeconds: dur,
                            sessionKey: sessionKey
                        )
                    } catch {
                        self.clearSession(for: sessionKey)
                    }
                }
            } else {
                self.clearSession(for: sessionKey)
            }
            
            timer.cancel()
        }
        
        timer.resume()
        expiryTasks[sessionKey] = timer
    }
}
