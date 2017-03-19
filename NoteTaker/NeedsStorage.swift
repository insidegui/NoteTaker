//
//  NeedsStorage.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 10/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import NoteTakerCore

protocol NeedsStorage: class {
    
    var storage: NotesStorage? { get set }
    
}
