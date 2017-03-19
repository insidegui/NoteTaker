//
//  AppDelegate.swift
//  MobileNoteTaker
//
//  Created by Guilherme Rambo on 27/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import UIKit
import NoteTakerCore

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    private var syncEngine: NotesSyncEngine!
    private let storage = NotesStorage()
    
    var window: UIWindow?
    private var navigationController: UINavigationController!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        UIApplication.shared.registerForRemoteNotifications()
        
        setup()
        
        syncEngine = NotesSyncEngine(storage: storage)
        
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NotificationCenter.default.post(name: .notesDidChangeRemotely, object: nil, userInfo: userInfo)
    }

    func setup() {
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        window!.backgroundColor = .white
        
        let notesController = NotesTableViewController(storage: storage)
        
        navigationController = UINavigationController(rootViewController: notesController)
        
        window!.rootViewController = navigationController
        
        window!.makeKeyAndVisible()
    }

}

