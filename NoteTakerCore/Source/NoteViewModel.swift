//
//  NoteViewModel.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 10/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import IGListKit

public class NoteViewModel: NSObject, IGListDiffable {

    public let note: Note
    
    public lazy var title: String = {
        return self.note.body.firstLine.removingHTML
    }()
    
    public init(note: Note) {
        self.note = note
        
        super.init()
    }
    
    public func diffIdentifier() -> NSObjectProtocol {
        return note.identifier as NSObjectProtocol
    }
    
    public func isEqual(toDiffableObject object: IGListDiffable?) -> Bool {
        guard let other = object as? NoteViewModel else { return false }
        
        return other.note == self.note
    }
    
}
