//
//  Note.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 10/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

public struct Note {
    
    public let identifier: String
    public let createdAt: Date
    public var modifiedAt: Date
    public var body: String
    
    public init(body: String,
         identifier: String? = nil,
         createdAt: Date? = nil,
         modifiedAt: Date? = nil) {
        self.body = body
        self.identifier = identifier ?? UUID().uuidString
        self.createdAt = createdAt ?? Date()
        self.modifiedAt = modifiedAt ?? Date()
    }
    
}

extension Note {
    
    public static var empty: Note {
        return Note(body: "")
    }
    
}

extension Note: Equatable {
    
    public static func ==(lhs: Note, rhs: Note) -> Bool {
        return lhs.identifier == rhs.identifier
                && lhs.createdAt == rhs.createdAt
                && lhs.modifiedAt == rhs.modifiedAt
                && lhs.body == rhs.body
    }
    
}

