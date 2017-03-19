//
//  AppDelegate.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 10/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import NoteTakerCore

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.registerForRemoteNotifications(matching: NSRemoteNotificationType())
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        NotificationCenter.default.post(name: .notesDidChangeRemotely, object: nil, userInfo: userInfo)
    }

}

