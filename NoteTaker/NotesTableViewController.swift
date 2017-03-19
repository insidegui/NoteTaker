//
//  NotesTableViewController.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 10/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa
import NoteTakerCore

class NotesTableViewController: NSViewController, NeedsStorage {

    @IBOutlet weak var tableView: NSTableView!

    var storage: NotesStorage? {
        didSet {
            guard let storage = storage else { return }
            
            subscribe(to: storage)
        }
    }
    
    var notes = Variable<[Note]>([])
    
    var viewModels = [NoteViewModel]() {
        didSet {
            tableView.reloadData(withOldValue: oldValue, newValue: viewModels)
            
            // trigger table selection to make sure the selected note updates in the editor if needed
            perform(#selector(updateSelectedNote), with: nil, afterDelay: 0)
        }
    }
    
    lazy var selectedNote: Observable<Note?> = {
        return self.tableView.rx.selectedRow.map { selectedRow -> Note? in
            if let row = selectedRow {
                return self.viewModels[row].note
            } else {
                return nil
            }
        }
    }()
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        notes.asObservable()
            .map({ $0.map(NoteViewModel.init) })
            .subscribe { [weak self] event in
                switch event {
                case .next(let noteViewModels):
                    self?.viewModels = noteViewModels
                    break
                default: break
                }
        }.addDisposableTo(disposeBag)
    }
    
    private func subscribe(to storage: NotesStorage) {
        storage.allNotes.asObservable()
            .observeOn(MainScheduler.instance)
            .bindTo(notes)
            .addDisposableTo(disposeBag)
    }
    
    @objc func selectLatestNote() {
        tableView.rx.selectedRow.onNext(0)
    }
    
    @objc func updateSelectedNote() {
        // "flick" selection to force-refresh the note being edited
        let selection = self.tableView.selectedRow
        tableView.rx.selectedRow.onNext(nil)
        tableView.rx.selectedRow.onNext(selection)
    }
    
    @IBAction func delete(_ sender: Any) {
        let identifiers = tableView.selectedRowIndexes.map({ viewModels[$0].note.identifier })
        
        do {
            try identifiers.forEach({ try storage?.delete(with: $0) })
        } catch {
            let alert = NSAlert(error: error)
            
            if let window = view.window {
                alert.beginSheetModal(for: window, completionHandler: nil)
            } else {
                alert.runModal()
            }
        }
    }
    
}

extension NotesTableViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModels.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < viewModels.count else { return nil }
        
        let cell: NSTableCellView? = tableView.make(withIdentifier: "cell", owner: tableView) as? NSTableCellView
        
        cell?.textField?.stringValue = viewModels[row].title
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableRowActionEdge) -> [NSTableViewRowAction] {
        let deleteAction = NSTableViewRowAction(style: .destructive, title: "Delete") { _, row in
            guard row < self.viewModels.count else { return }
            let note = self.viewModels[row].note
            
            do {
                try self.storage?.delete(with: note.identifier)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        
        return [deleteAction]
    }
    
}
