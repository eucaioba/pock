//
//  CCDoNotDisturbItem.swift
//  Pock
//
//  Created by Licardo on 2019/12/7.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Foundation
import Defaults

class CCDoNotDisturbItem: ControlCenterItem {
    /// The legacy `com.apple.notificationcenterui` preferences stopped controlling Do Not Disturb when Focus replaced it in macOS 12.
    override var enabled: Bool {
        if #available(macOS 12.0, *) { return false }
        return Defaults[.shouldShowDoNotDisturbItem]
    }
    
    override var title: String { return "do-not-disturb" }
    
    override func action() -> Any? {
        if !Defaults[.isDoNotDisturb] {
            enableDND()
            Defaults[.isDoNotDisturb] = true
        } else {
            disableDND()
            Defaults[.isDoNotDisturb] = false
        }
        return nil
    }
    
    func enableDND(){
        CFPreferencesSetValue("dndStart" as CFString, CGFloat(0) as CFPropertyList, "com.apple.notificationcenterui" as CFString, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSetValue("dndEnd" as CFString, CGFloat(1440) as CFPropertyList, "com.apple.notificationcenterui" as CFString, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSetValue("doNotDisturb" as CFString, true as CFPropertyList, "com.apple.notificationcenterui" as CFString, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        commitDNDChanges()
        
    }
    
    func disableDND(){
        CFPreferencesSetValue("dndStart" as CFString, nil, "com.apple.notificationcenterui" as CFString, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSetValue("dndEnd" as CFString, nil, "com.apple.notificationcenterui" as CFString, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSetValue("doNotDisturb" as CFString, false as CFPropertyList, "com.apple.notificationcenterui" as CFString, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        commitDNDChanges()
    }
    
    func commitDNDChanges(){
        CFPreferencesSynchronize("com.apple.notificationcenterui" as CFString, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        DistributedNotificationCenter.default().postNotificationName(NSNotification.Name(rawValue: "com.apple.notificationcenterui.dndprefs_changed"), object: nil, userInfo: nil, deliverImmediately: true)
    }
}
