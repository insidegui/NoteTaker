//
//  RealmNote.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 12/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

final class RealmNote: Object {
    
    dynamic var identifier = ""
    dynamic var createdAt = Date()
    dynamic var modifiedAt = Date()
    dynamic var body = ""
    dynamic var isDeleted = false
    
    override class func primaryKey() -> String? {
        return "identifier"
    }
    
    static func ==(lhs: RealmNote, rhs: RealmNote) -> Bool {
        return lhs.note == rhs.note && lhs.isDeleted == rhs.isDeleted
    }
    
}
