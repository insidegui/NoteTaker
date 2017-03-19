//
//  NotesSplitViewController.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 10/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxOptional
import RxCocoa
import CloudKit
import NoteTakerCore

/**
 NOTE: The code in this controller should probably live in a coordinator or something
 I usually avoid storyboards but used them here because this is a prototype, sample app
 */

class NotesSplitViewController: NSSplitViewController {

    private let disposeBag = DisposeBag()
    
    lazy var storage: NotesStorage = {
        return NotesStorage()
    }()
    
    var syncEngine: NotesSyncEngine!
    
    var notesController: NotesTableViewController {
        return childViewControllers[0] as! NotesTableViewController
    }
    
    var editorController: NoteEditorViewController {
        return childViewControllers[1] as! NoteEditorViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        childViewControllers.flatMap({ $0 as? NeedsStorage }).forEach({ $0.storage = storage })
        
        syncEngine = NotesSyncEngine(storage: storage)
        
        view.wantsLayer = true
        
        notesController.selectedNote
                        .asObservable()
                        .replaceNilWith(.empty)
                        .bindTo(editorController.note)
                        .addDisposableTo(disposeBag)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        setupWindowStuff()
    }
    
    // Ideally, this window and toolbar setup code would live in a window controller, but this is just a prototype ;)
    private func setupWindowStuff() {
        guard let window = view.window else { return }
        
        window.titleVisibility = .hidden
        
        guard let toolbar = window.toolbar else { return }
        
        let flexibleItems = toolbar.items.flatMap({ $0 as? NSToolbarFlexibleSpaceItem })
        
        guard flexibleItems.count > 1 else { return }
        
        flexibleItems[1].trackedSplitView = self.splitView
    }
    
    @IBAction func newNote(_ sender: Any?) {
        let note = Note(body: "New Note")
        
        do {
            try storage.store(note: note)
        } catch {
            NSAlert(error: error).runModal()
        }
        
        // make sure selectLatestNote is executed after the current runloop cycle so the recently created note is already there
        notesController.perform(#selector(NotesTableViewController.selectLatestNote), with: nil, afterDelay: 0)
    }
    
    @IBAction func shareNote(_ sender: Any?) {
        guard let window = view.window else { return }
        
        let alert = NSAlert()
        alert.messageText = "Sharing Not Available"
        alert.informativeText = "Sharing is not implemented yet"
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window, completionHandler: nil)
    }
    
}
