//
//  NotesStorage.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 10/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import RxRealm
import RxSwift

enum StorageError: Error {
    case recordNotFound(String)
    
    var localizedDescription: String {
        switch self {
        case .recordNotFound(let identifier):
            return "Record not found with primary key \(identifier)"
        }
    }
}

/// This class is responsible for the management of the local database (fetching, saving and deleting notes)
public final class NotesStorage {
    
    typealias UpdateDecisionHandler<T> = (_ oldObject: T, _ newObject: T) -> Bool
    
    let realm: Realm
    
    init(realm: Realm? = nil) {
        if let r = realm {
            self.realm = r
        } else {
            self.realm = try! Realm()
        }
    }
    
    public convenience init() {
        self.init(realm: nil)
    }
    
    public var allNotes: Observable<[Note]> {
        // Instead of immediately deleting notes when they are deleted in the UI,
        // we simply set a flag on them that is used to delete the record on the Cloud
        // This is necessary because of the way Realm collection notifications work,
        // it is the best workaround I've found
        let objects = self.realm.objects(RealmNote.self)
                                .filter(NSPredicate(format: "isDeleted == false"))
                                .sorted(byKeyPath: "modifiedAt", ascending: false)
        
        return Observable.collection(from: objects).map { realmNotes in
            return realmNotes.map({ $0.note })
        }
    }
    
    var mostRecentlyModifiedNote: Note? {
        let realmNotes = realm.objects(RealmNote.self)
                              .sorted(byKeyPath: NoteKey.modifiedAt.rawValue, ascending: false)
        
        return realmNotes.first?.note
    }
    
    public func store(note: Note) throws {
        try store(realmNote: note.realmNote)
    }
    
    func store(realmNote: RealmNote, notNotifying token: NotificationToken? = nil) throws {
        try insertOrUpdate(object: realmNote, notNotifying: token) { oldNote, newNote in
            guard newNote != oldNote else { return false }
            
            return newNote.modifiedAt > oldNote.modifiedAt
        }
    }
    
    public func delete(with identifier: String, hard reallyDelete: Bool = false) throws {
        guard let note = realm.object(ofType: RealmNote.self, forPrimaryKey: identifier) else {
            throw StorageError.recordNotFound(identifier)
        }
        
        try realm.write {
            if reallyDelete {
                self.realm.delete(note)
            } else {
                note.isDeleted = true
                self.realm.add(note, update: true)
            }
        }
    }
    
    func deletePreviouslySoftDeletedNotes(notNotifying token: NotificationToken? = nil) throws {
        let objects = realm.objects(RealmNote.self).filter("isDeleted = true")
        
        let tokens: [NotificationToken]
        
        if let token = token {
            tokens = [token]
        } else {
            tokens = []
        }
        
        realm.beginWrite()
        objects.forEach({ realm.delete($0) })
        try realm.commitWrite(withoutNotifying: tokens)
    }
    
    private func insertOrUpdate<T: Object>(objects: [T],
                                notNotifying token: NotificationToken? = nil,
                                updateDecisionHandler: @escaping UpdateDecisionHandler<T>) throws {
        try objects.forEach({ try self.insertOrUpdate(object: $0, notNotifying: token, updateDecisionHandler: updateDecisionHandler) })
    }
    
    private func insertOrUpdate<T: Object>(object: T,
                                notNotifying token: NotificationToken? = nil,
                                updateDecisionHandler: @escaping UpdateDecisionHandler<T>) throws {
        guard let primaryKey = T.primaryKey() else {
            fatalError("insertOrUpdate can't be used for objects without a primary key")
        }
        
        guard let primaryKeyValue = object.value(forKey: primaryKey) else {
            fatalError("insertOrUpdate can't be used for objects without a primary key")
        }
        
        let tokens: [NotificationToken]
        
        if let token = token {
            tokens = [token]
        } else {
            tokens = []
        }
        
        if let existingObject = realm.object(ofType: T.self, forPrimaryKey: primaryKeyValue) {
            // object already exists, call updateDecisionHandler to determine whether we should update it or not
            if updateDecisionHandler(existingObject, object) {
                realm.beginWrite()
                realm.add(object, update: true)
                try realm.commitWrite(withoutNotifying: tokens)
            }
        } else {
            // object doesn't exist, just add it
            realm.beginWrite()
            realm.add(object)
            try realm.commitWrite(withoutNotifying: tokens)
        }
    }
    
}
