import Foundation

#if !os(macOS)
import UIKit
#endif

import Cocoa

public enum SafariVersion: Int {
    // AdGuard for iOS supports Safari from 11 version
    // AdGuard for Safari doesn't support OS Sierra, so minimal Safari version is 13
    @available (OSX, unavailable)
    case safari11 = 11;
    @available (OSX, unavailable)
    case safari12 = 12;
    
    case safari13 = 13;
    case safari14 = 14;
    case safari15 = 15;
    
    /**
     * Returns rules limit for current Safari version
     * Safari allows up to 50k rules by default, but starting from 15 version it allows up to 150k rules
     */
    var rulesLimit: Int {
        switch self {
            case .safari11, .safari12, .safari13, .safari14: return 50000
            case .safari15: return 150000
        }
    }
    
    func isSafari15() -> Bool {
        return self == SafariVersion.safari15;
    }
}

public class SafariService {
    public var version: SafariVersion = .safari13;
    public static let current: SafariService = SafariService();
    
    init() {
        var safariVersion: SafariVersion;
        
        #if os(macOS)
            let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari")!;
            let bundle = Bundle(url: bundleURL)!;
            let safariVersionString = bundle.infoDictionary?["CFBundleShortVersionString"] as? String;
            safariVersion = SafariVersion(rawValue: Int(safariVersionString!.prefix(2))!)!;
        #else
            let systemVersion = UIDevice.current.systemVersion as? String;
            safariVersion = SafariVersion(rawValue: Int(systemVersion!.prefix(2))!)!;
        #endif
        
        self.version = safariVersion;
    }
    
    init (version: SafariVersion) {
        self.version = version;
    }
}

public enum SafariVersionError: Error {
    case invalidSafariVersion(message: String = "Invalid Safari version value")
    case unsupportedSafariVersion(message: String = "The provided Safari version is not supported")
}
