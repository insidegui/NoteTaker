//
//  NotesSyncEngine.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 11/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import RxRealm
import RxSwift
import CloudKit

extension CKContainer {
    static let noteTakerShared = CKContainer(identifier: "iCloud.br.com.guilhermerambo.NoteTakerShared")
}

extension Notification.Name {
    public static let notesDidChangeRemotely = Notification.Name(rawValue: "NotesDidChangeRemotely")
}

private func slog(_ format: String, _ args: CVarArg...) {
    guard ProcessInfo.processInfo.arguments.contains("--log-sync") else { return }
    
    NSLog("[SYNC] " + format, args)
}

/// This class is responsible for observing changes to the local database and pushing them to CloudKit
/// as well as observing changes in CloudKit and syncing them to the local database
public final class NotesSyncEngine: NSObject {
    
    private struct Constants {
        static let previousChangeToken = "PreviousChangeToken"
        static let noteRecordType = "Note"
    }
    
    /// The CloudKit container the sync engine is using
    private let container: CKContainer
    
    /// The user's private CloudKit database
    private let privateDatabase: CKDatabase
    
    /// Local storage controller
    private let storage: NotesStorage
    
    /// Initializes the sync engine with a local storage
    public init(storage: NotesStorage, container: CKContainer = .noteTakerShared) {
        self.storage = storage
        self.container = container
        self.privateDatabase = container.privateCloudDatabase
        
        super.init()
        
        // Do initial cloud fetch
        fetchCloudKitNotes()
        
        // Fetch notifications not processed yet
        fetchServerNotifications()
        
        // Sync magic
        subscribeToLocalDatabaseChanges()
        subscribeToCloudKitChanges()
        
        // Clean database before the app terminates
        #if os(macOS)
            NotificationCenter.default.addObserver(self, selector: #selector(cleanup(_:)), name: .NSApplicationWillTerminate, object: NSApp)
        #else
            NotificationCenter.default.addObserver(self, selector: #selector(cleanup(_:)), name: .UIApplicationWillTerminate, object: UIApplication.shared)
        #endif
    }
    
    /// The modification date of the last note modified locally to use when querying the server
    private var modificationDateForQuery: Date {
        return storage.mostRecentlyModifiedNote?.modifiedAt ?? Date.distantPast
    }
    
    /// Download notes from CloudKit
    private func fetchCloudKitNotes(_ inputCursor: CKQueryCursor? = nil) {
        let operation: CKQueryOperation
        
        // We may be starting a new query or continuing a previous one if there are many results
        if let cursor = inputCursor {
            operation = CKQueryOperation(cursor: cursor)
        } else {
            // This query will fetch all notes modified since the last sync, sorted by modification date (descending)
            let predicate = NSPredicate(format: "modifiedAt > %@", modificationDateForQuery as CVarArg)
            let query = CKQuery(recordType: Constants.noteRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: NoteKey.modifiedAt.rawValue, ascending: false)]
            operation = CKQueryOperation(query: query)
        }
        
        operation.queryCompletionBlock = { [weak self] cursor, error in
            guard error == nil else {
                self?.retryCloudKitOperationIfPossible(with: error) {
                    self?.fetchCloudKitNotes(inputCursor)
                }
                
                return
            }

            if let cursor = cursor {
                // There are more results to come, continue fetching
                self?.fetchCloudKitNotes(cursor)
            }
        }
        
        operation.recordFetchedBlock = { [weak self] record in
            // When a note is fetched from the cloud, process it into the local database
            self?.processFetchedNote(record)
        }
        
        privateDatabase.add(operation)
    }
    
    private let disposeBag = DisposeBag()
    
    /// Realm collection notification token
    private var notificationToken: NotificationToken?
    
    private func subscribeToLocalDatabaseChanges() {
        let notes = storage.realm.objects(RealmNote.self)
        
        // Here we subscribe to changes in notes to push them to CloudKit
        notificationToken = notes.addNotificationBlock { [weak self] changes in
            guard let welf = self else { return }
            
            switch changes {
            case .update(let collection, _, let insertions, let modifications):
                // Figure out which notes should be saved and which notes should be deleted
                let notesToSave = (insertions + modifications).map({ collection[$0] }).filter({ !$0.isDeleted })
                let notesToDelete = modifications.map({ collection[$0] }).filter({ $0.isDeleted })
                
                // Push changes to CloudKitx
                welf.pushToCloudKit(notesToUpdate: notesToSave, notesToDelete: notesToDelete)
            case .error(let error):
                slog("Realm notification error: \(error)")
            default: break
            }
        }
    }
    
    fileprivate func pushToCloudKit(notesToUpdate: [RealmNote], notesToDelete: [RealmNote]) {
        guard notesToUpdate.count > 0 || notesToDelete.count > 0 else { return }
        
        slog("\(notesToUpdate.count) note(s) to save, \(notesToDelete.count) note(s) to delete")
        
        let recordsToSave = notesToUpdate.map({ $0.record })
        let recordsToDelete = notesToDelete.map({ $0.recordID })
        
        pushRecordsToCloudKit(recordsToUpdate: recordsToSave, recordIDsToDelete: recordsToDelete)
    }
    
    fileprivate func pushRecordsToCloudKit(recordsToUpdate: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())? = nil) {
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToUpdate, recordIDsToDelete: recordIDsToDelete)
        operation.savePolicy = .changedKeys
        
        operation.modifyRecordsCompletionBlock = { [weak self] _, _, error in
            guard error == nil else {
                slog("Error modifying records: \(error!)")
                
                self?.retryCloudKitOperationIfPossible(with: error) {
                    self?.pushRecordsToCloudKit(recordsToUpdate: recordsToUpdate,
                                                recordIDsToDelete: recordIDsToDelete,
                                                completion: completion)
                }
                return
            }
            
            slog("Finished saving records")
            
            DispatchQueue.main.async {
                completion?(nil)
            }
        }
        
        privateDatabase.add(operation)
    }
    
    private func subscribeToCloudKitChanges() {
        startObservingCloudKitChanges()
        
        // Create the CloudKit subscription so we receive push notifications when notes change remotely
        let subscription = CKQuerySubscription(recordType: Constants.noteRecordType,
                                               predicate: NSPredicate(value: true),
                                               options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
        
        let info = CKNotificationInfo()
        info.shouldSendContentAvailable = true
        info.soundName = ""
        subscription.notificationInfo = info
        
        privateDatabase.save(subscription) { [weak self] subscription, error in
            if subscription != nil {
                slog("Successfully subscribed to cloud database changes")
            } else {
                guard error == nil else {
                    self?.retryCloudKitOperationIfPossible(with: error) {
                        self?.subscribeToCloudKitChanges()
                    }
                    return
                }
            }
        }
    }
    
    /// Holds the latest change token we got from CloudKit, storing it in UserDefaults
    private var previousChangeToken: CKServerChangeToken? {
        get {
            guard let tokenData = UserDefaults.standard.object(forKey: Constants.previousChangeToken) as? Data else { return nil }
            
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let newValue = newValue else {
                UserDefaults.standard.setNilValueForKey(Constants.previousChangeToken)
                return
            }
            
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            
            UserDefaults.standard.set(data, forKey: Constants.previousChangeToken)
        }
    }
    
    // CloudKit notes observer
    private var changesObserver: NSObjectProtocol?
    
    private func startObservingCloudKitChanges() {
        // The .notesDidChangeRemotely local notification is posted by the AppDelegate when it receives a push notification from CloudKit
        changesObserver = NotificationCenter.default.addObserver(forName: .notesDidChangeRemotely,
                                                                 object: nil,
                                                                 queue: OperationQueue.main)
        { [weak self] note in
            // When a notification is received from the server, we must download the notifications because they might have been coalesced
            self?.fetchServerNotifications()
        }
    }
    
    private func fetchServerNotifications() {
        // Lock syncing
        guard !isSyncing else { return }
        isSyncing = true
        
        let operation = CKFetchNotificationChangesOperation(previousServerChangeToken: previousChangeToken)
        
        // This will hold the identifiers for every changed record
        var updatedIdentifiers = [CKRecordID]()
        
        // This will hold the notification IDs we processed so we can tell CloudKit to never send them to us again
        var notificationIDs = [CKNotificationID]()
        
        operation.notificationChangedBlock = { [weak self] notification in
            guard let notification = notification as? CKQueryNotification else { return }
            guard let identifier = notification.recordID else { return }
            
            if let id = notification.notificationID {
                notificationIDs.append(id)
            }
            
            DispatchQueue.main.async {
                switch notification.queryNotificationReason {
                case .recordDeleted:
                    do {
                        try self?.storage.delete(with: identifier.recordName, hard: true)
                    } catch {
                        slog("Error deleting note from cloud instruction: \(error)")
                    }
                default:
                    updatedIdentifiers.append(identifier)
                }
            }
        }
        
        operation.fetchNotificationChangesCompletionBlock = { [weak self] newToken, error in
            guard error == nil else {
                self?.retryCloudKitOperationIfPossible(with: error) {
                    self?.fetchServerNotifications()
                }
                
                self?.isSyncing = false
                
                return
            }
            
            self?.previousChangeToken = newToken
            
            // All records are in, now save the data locally
            self?.consolidateUpdatedCloudNotes(with: updatedIdentifiers)
            
            // Tell CloudKit we've read the notifications
            self?.markNotificationsAsRead(with: notificationIDs)
        }
        
        container.add(operation)
    }
    
    private func markNotificationsAsRead(with identifiers: [CKNotificationID]) {
        let operation = CKMarkNotificationsReadOperation(notificationIDsToMarkRead: identifiers)
        
        operation.markNotificationsReadCompletionBlock = { [weak self] _, error in
            guard error == nil else {
                self?.retryCloudKitOperationIfPossible(with: error) {
                    self?.markNotificationsAsRead(with: identifiers)
                }
                
                return
            }
        }
        
        container.add(operation)
    }
    
    private var isSyncing = false
    
    /// Download a list of records from CloudKit and update the local database accordingly
    private func consolidateUpdatedCloudNotes(with identifiers: [CKRecordID]) {
        let operation = CKFetchRecordsOperation(recordIDs: identifiers)
        
        operation.fetchRecordsCompletionBlock = { [weak self] records, error in
            guard let records = records else {
                self?.retryCloudKitOperationIfPossible(with: error) {
                    self?.consolidateUpdatedCloudNotes(with: identifiers)
                }
                return
            }
            
            records.values.forEach { record in
                self?.processFetchedNote(record)
            }
        }
        
        operation.completionBlock = { [weak self] in
            self?.isSyncing = false
        }
        
        privateDatabase.add(operation)
    }
    
    /// Sync a single note to the local database
    private func processFetchedNote(_ cloudKitNote: CKRecord) {
        DispatchQueue.main.async {
            guard let note = RealmNote.from(record: cloudKitNote) else {
                slog("Error creating local note from cloud note \(cloudKitNote.recordID.recordName)")
                return
            }
            
            do {
                try self.storage.store(realmNote: note, notNotifying: self.notificationToken)
            } catch {
                slog("Error saving local note from cloud note \(cloudKitNote.recordID.recordName): \(error)")
            }
        }
    }
    
    @objc func cleanup(_ notification: Notification? = nil) {
        do {
            try storage.deletePreviouslySoftDeletedNotes(notNotifying: self.notificationToken)
        } catch {
            NSLog("Failed to delete previously soft deleted notes: \(error)")
        }
    }
    
    // MARK: - Util
    
    /// Helper method to retry a CloudKit operation when its error suggests it
    private func retryCloudKitOperationIfPossible(with error: Error?, block: @escaping () -> ()) {
        guard let error = error as? CKError else {
            slog("CloudKit puked ¯\\_(ツ)_/¯")
            return
        }
        
        guard let retryAfter = error.userInfo[CKErrorRetryAfterKey] as? NSNumber else {
            slog("CloudKit error: \(error)")
            return
        }
        
        slog("CloudKit operation error, retrying after \(retryAfter) seconds...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + retryAfter.doubleValue) {
            block()
        }
    }
    
}
