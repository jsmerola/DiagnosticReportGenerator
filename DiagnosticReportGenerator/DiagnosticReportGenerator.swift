//
//  DiagnosticReportGenerator.swift
//
//  Created by Jeff Merola on 6/16/15.
//  Copyright © 2015 Jeff Merola. All rights reserved.
//

import Foundation
import SystemConfiguration

#if os(iOS)
    import UIKit
    #elseif os(OSX)
    import AppKit
    import IOKit.ps
#endif

@available (iOS 8.0, OSX 10.10, *)
public class DiagnosticReportGenerator: NSObject {
    
    /**
    Possible errors that can be thrown by generateWithIdentifier(_:extraInfo:includeDefaults:)
    
    - TemplateNotFound: The diagnostic report template file is missing from the project.
    - TemplateParseError: The contents of the report template could not be read.
    */
    public enum ReportError: ErrorType {
        case TemplateNotFound
        case TemplateParseError
    }
    
    /**
    Generates a diagnostic report.
    
    :param: identifer       The identifier to use for the generated report. If nil, a random UUID will be generated.
    :param: extraInfo       An optional dictionary of additional information to be included in the report. The keys and values are printed using Swift's string interpolation feature.
    :param: includeDefaults A boolean specifying whether to include NSUserDefaults in the report or not. Defaults to true.
    
    :returns: A diagnostic report as a String, formatted as html.
    */
    public func generateWithIdentifier(identifier: String?, extraInfo: [String: AnyObject]?, includeDefaults: Bool = true) throws -> String {
        
        guard let path = NSBundle.mainBundle().pathForResource("DiagnosticReportTemplate", ofType: "html") else {
            throw ReportError.TemplateNotFound
        }
        
        let reportTemplate: String
        do {
            reportTemplate = try String(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        } catch {
            throw ReportError.TemplateParseError
        }
        
        let args: [CVarArgType] = [
            
            Timestamp(),
            identifier ?? NSUUID().UUIDString,
            DeviceName(),
            Model(),
            SystemVersion(),
            CPUCountString(),
            BatteryStateString(),
            BatteryLevelString(),
            SystemUptime(),
            TotalDiskSpaceString(),
            FreeDiskSpaceString(),
            ScreenInformation(),
            SystemLocale(),
            Timezone(),
            ApplicationName(),
            ApplicationBundleID(),
            ApplicationVersion(),
            ApplicationBuild(),
            BuildAdditionalAppInfoStringFromDictionary(extraInfo),
            includeDefaults ? UserDefaults() : "Not Included",
            
            ].map { (value: CVarArgType) -> CVarArgType in
                if let value = value as? String {
                    return value.htmlRepresentation() as CVarArgType
                } else {
                    return "" as CVarArgType
                }
        }
        
        return withVaList(args, { (pointer: CVaListPointer) -> String in
            NSString(format: reportTemplate, arguments: pointer) as String
        })
    }
}

// MARK: - Hardware Info
@available(iOS 8.0, OSX 10.10, *)
private extension DiagnosticReportGenerator {
    func GetSystemInfoByName(name: String) -> String? {
        var size: Int = 0
        sysctlbyname(name, nil, &size, nil, 0)
        
        var info = [CChar](count: size, repeatedValue: 0)
        sysctlbyname(name, &info, &size, nil, 0)
        return String.fromCString(info)
    }
    
    func Model() -> String {
        let machine = GetSystemInfoByName("hw.machine") ?? "?"
        let model = GetSystemInfoByName("hw.model") ?? "?"
        return "\(model) - \(machine)"
    }
    
    func CPUCount() -> Int {
        return NSProcessInfo.processInfo().processorCount
    }
    
    func CPUCountString() -> String {
        return "\(CPUCount())"
    }
    
    func ScreenInformation() -> String {
        #if os(iOS)
            return "\(NSStringFromCGSize(UIScreen.mainScreen().bounds.size))@\(UIScreen.mainScreen().scale)x"
            #elseif os(OSX)
            var screenStrings = Array<String>()
            if let screens = NSScreen.screens() {
            var index = 0
            for screen in screens {
            screenStrings.append("[ Screen #\(++index): {\(Int(screen.frame.size.width)), \(Int(screen.frame.size.height))}@\(screen.backingScaleFactor)x ]")
            }
            }
            return (screenStrings as NSArray).componentsJoinedByString(", ")
            #else
            return "?"
        #endif
    }
}

// MARK: - Disk Info
@available(iOS 8.0, OSX 10.10, *)
private extension DiagnosticReportGenerator {
    func TotalDiskSpace() -> Int64 {
        do {
            if let totalSpace = try NSFileManager.defaultManager().attributesOfFileSystemForPath(NSHomeDirectory())[NSFileSystemSize] as? Int {
                return Int64(totalSpace)
            } else {
                return -1
            }
        } catch {
            return -1
        }
    }
    
    func TotalDiskSpaceString() -> String {
        let space = TotalDiskSpace()
        if space < 0 {
            return "?"
        } else {
            let formatter = NSByteCountFormatter()
            formatter.countStyle = .File
            formatter.includesActualByteCount = true
            return formatter.stringFromByteCount(space)
        }
    }
    
    func FreeDiskSpace() -> Int64 {
        do {
            if let freeSpace = try NSFileManager.defaultManager().attributesOfFileSystemForPath(NSHomeDirectory())[NSFileSystemFreeSize] as? Int {
                return Int64(freeSpace)
            } else {
                return -1
            }
        } catch {
            return -1
        }
    }
    
    func FreeDiskSpaceString() -> String {
        let space = FreeDiskSpace()
        if space < 0 {
            return "?"
        } else {
            let formatter = NSByteCountFormatter()
            formatter.countStyle = .File
            formatter.includesActualByteCount = true
            return formatter.stringFromByteCount(space)
        }
    }
}

// MARK: - Battery Info
@available(iOS 8.0, OSX 10.10, *)
private extension DiagnosticReportGenerator {
    enum ChargeState: CustomStringConvertible {
        case Charging, Charged, Draining, Unknown
        
        var description: String {
            switch self {
            case .Charging:
                return "Charging"
            case .Charged:
                return "Fully Charged"
            case .Draining:
                return "Draining"
            case .Unknown:
                return "Unknown"
            }
        }
    }
    
    #if os(OSX)
    func PowerSource() -> NSDictionary {
    let powerSourceInfoDict = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let powerSources = IOPSCopyPowerSourcesList(powerSourceInfoDict).takeRetainedValue() as Array
    if powerSources.count > 0 {
    return IOPSGetPowerSourceDescription(powerSourceInfoDict, powerSources[0]).takeUnretainedValue() as NSDictionary
    }
    return [:]
    }
    #endif
    
    func BatteryState() -> ChargeState {
        #if os(iOS)
            UIDevice.currentDevice().batteryMonitoringEnabled = true
            let state: ChargeState
            switch UIDevice.currentDevice().batteryState {
            case .Unknown:
                state = .Unknown
            case .Unplugged:
                state = .Draining
            case .Charging:
                state = .Charging
            case .Full:
                state = .Charged
            }
            UIDevice.currentDevice().batteryMonitoringEnabled = false
            return state
            #elseif os(OSX)
            let powerSource = PowerSource()
            let state = powerSource[kIOPSPowerSourceStateKey] as! String
            switch state {
            case kIOPSACPowerValue:
            if powerSource[kIOPSIsChargingKey] as! Bool == true {
            return .Charging
            } else if powerSource[kIOPSIsChargedKey] as! Bool == true {
            return .Charged
            } else {
            return .Unknown
            }
            case kIOPSBatteryPowerValue:
            return .Draining
            default:
            return .Unknown
            }
            #else
            return .Unknown
        #endif
    }
    
    func BatteryStateString() -> String {
        return "\(BatteryState())"
    }
    
    func BatteryLevel() -> Float {
        #if os(iOS)
            UIDevice.currentDevice().batteryMonitoringEnabled = true
            let batteryLevel = UIDevice.currentDevice().batteryLevel * 100
            UIDevice.currentDevice().batteryMonitoringEnabled = false
            return batteryLevel
            #elseif os(OSX)
            let powerSource = PowerSource()
            let state = BatteryState()
            switch state {
            case .Draining, .Charging:
            let currentCapacity = powerSource[kIOPSCurrentCapacityKey] as! Float
            let maxCapacity = powerSource[kIOPSMaxCapacityKey] as! Float
            return currentCapacity / maxCapacity * 100
            case .Charged:
            return 100
            case .Unknown:
            return -1
            }
            #else
            return -1
        #endif
    }
    
    func BatteryLevelString() -> String {
        let level = BatteryLevel()
        if level < 0 {
            return "?"
        } else {
            return "\(level)%"
        }
    }
}

// MARK: - Software Info
@available(iOS 8.0, OSX 10.10, *)
private extension DiagnosticReportGenerator {
    func DeviceName() -> String {
        #if os(iOS)
            return UIDevice.currentDevice().name
            #elseif os(OSX)
            if let name = SCDynamicStoreCopyComputerName(nil, nil) {
            return name as String
            } else {
            return "?"
            }
            #else
            return "?"
        #endif
    }
    
    private func SystemVersion() -> String {
        return NSProcessInfo.processInfo().operatingSystemVersionString
    }
    
    private func SystemUptime() -> String {
        let uptime = NSProcessInfo.processInfo().systemUptime
        let formatter = NSDateComponentsFormatter()
        formatter.unitsStyle = .Short
        return formatter.stringFromTimeInterval(uptime) ?? "?"
    }
}

// MARK: - Application Info
@available(iOS 8.0, OSX 10.10, *)
private extension DiagnosticReportGenerator {
    func ApplicationName() -> String {
        return NSBundle.mainBundle().applicationName ?? "?"
    }
    
    func ApplicationBundleID() -> String {
        return NSBundle.mainBundle().bundleIdentifier ?? "?"
    }
    
    func ApplicationVersion() -> String {
        return NSBundle.mainBundle().applicationVersion ?? "?"
    }
    
    func ApplicationBuild() -> String {
        return NSBundle.mainBundle().applicationBuild ?? "?"
    }
}

// MARK: - Locale/Time Info
@available(iOS 8.0, OSX 10.10, *)
private extension DiagnosticReportGenerator {
    func Timestamp() -> String {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZ"
        return dateFormatter.stringFromDate(NSDate())
    }
    
    func SystemLocale() -> String {
        return NSLocale.currentLocale().localeIdentifier
    }
    
    func Timezone() -> String {
        return NSTimeZone.localTimeZone().name
    }
}

// MARK: - Additional Info
@available(iOS 8.0, OSX 10.10, *)
private extension DiagnosticReportGenerator {
    func BuildAdditionalAppInfoStringFromDictionary(info: [String: AnyObject]?) -> String {
        guard let appInfo = info else { return "" }
        
        var result = ""
        for (key, value) in appInfo {
            result += "\(key): \(value)\n"
        }
        
        return result
    }
    
    func UserDefaults() -> String {
        return "\(NSUserDefaults.standardUserDefaults().dictionaryRepresentation())"
    }
}

// MARK: - NSBundle Convenience Methods
private extension NSBundle {
    var applicationName: String? {
        return objectForInfoDictionaryKey("CFBundleName") as? String
    }
    var applicationVersion: String? {
        return objectForInfoDictionaryKey("CFBundleShortVersionString") as? String
    }
    var applicationBuild: String? {
        return objectForInfoDictionaryKey("CFBundleVersion") as? String
    }
}

// MARK: HTML String
private extension String {
    func htmlRepresentation() -> String {
        var result = self.stringByReplacingOccurrencesOfString("&", withString: "&amp;")
        result = result.stringByReplacingOccurrencesOfString("<", withString: "&lt;")
        return result.stringByReplacingOccurrencesOfString(">", withString: "&gt;") ?? ""
    }
}
