//
//  RealmNote+CKRecord.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 12/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit
import RealmSwift

enum NoteKey: String {
    case identifier, createdAt, modifiedAt, body
}

extension CKRecord {
    
    subscript(_ key: NoteKey) -> CKRecordValue {
        get {
            return self[key.rawValue]!
        }
        set {
            self[key.rawValue] = newValue
        }
    }
    
}

extension RealmNote {
    
    var recordID: CKRecordID {
        return CKRecordID(recordName: identifier)
    }
    
    var record: CKRecord {
        let record = CKRecord(recordType: "Note", recordID: recordID)
        
        record[.identifier] = identifier as CKRecordValue
        record[.createdAt] = createdAt as CKRecordValue
        record[.modifiedAt] = modifiedAt as CKRecordValue
        record[.body] = body as CKRecordValue
        
        return record
    }
    
    static func from(record: CKRecord) -> RealmNote? {
        guard let identifier = record[.identifier] as? String,
            let createdAt = record[.createdAt] as? Date,
            let modifiedAt = record[.modifiedAt] as? Date,
            let body = record[.body] as? String
            else {
                return nil
        }
        
        let note = RealmNote()
        
        note.identifier = identifier
        note.createdAt = createdAt
        note.modifiedAt = modifiedAt
        note.body = body
        
        return note
    }
    
}
