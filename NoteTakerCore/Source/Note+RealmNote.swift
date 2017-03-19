//
//  Note+RealmNote.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 12/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

extension Note {
    
    init(realmNote: RealmNote) {
        self.identifier = realmNote.identifier
        self.body = realmNote.body
        self.createdAt = realmNote.createdAt
        self.modifiedAt = realmNote.modifiedAt
    }
    
    var realmNote: RealmNote {
        let note = RealmNote()
        
        note.identifier = identifier
        note.body = body
        note.createdAt = createdAt
        note.modifiedAt = modifiedAt
        
        return note
    }
    
}

extension RealmNote {
    
    var note: Note {
        return Note(body: body,
                    identifier: identifier,
                    createdAt: createdAt,
                    modifiedAt: modifiedAt)
    }
    
}
