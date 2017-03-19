//
//  NoteEditorViewController.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 10/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa
import NoteTakerCore

class NoteEditorViewController: NSViewController, NeedsStorage {

    var note = Variable<Note>(.empty)
    var contents = Variable<String>("")
    
    var storage: NotesStorage?
    
    private let disposeBag = DisposeBag()
    
    private lazy var editor: NoteEditorView = {
        let e = NoteEditorView(frame: self.view.bounds)
        
        e.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        e.delegate = self
        
        return e
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(editor)
        
        // track selected note
        note.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] note in
                self?.updateNoteContents(with: note.body)
            }).addDisposableTo(disposeBag)
        
        // track note editing
        contents.asObservable()
            .observeOn(MainScheduler.instance)
            .distinctUntilChanged()
            .debounce(1, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] contents in
                self?.didEditNote(with: contents)
            }).addDisposableTo(disposeBag)
    }
    
    private func updateNoteContents(with body: String) {
        editor.setContents(body)
        
        view.window?.makeFirstResponder(editor)
    }
    
    fileprivate func didEditNote(with body: String) {
        var note = self.note.value
        
        guard note.body != body else { return }
        
        note.modifiedAt = Date()
        note.body = body
        
        do {
            try storage?.store(note: note)
        } catch {
            NSLog("Error storing note: \(error)")
        }
    }
    
}

extension NoteEditorViewController: NoteEditorViewDelegate {
    
    func noteEditorView(_ sender: NoteEditorView, contentsDidChange contents: String) {
        self.contents.value = contents
    }
    
}
