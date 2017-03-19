//
//  NotesTableViewController.swift
//  MobileNoteTaker
//
//  Created by Guilherme Rambo on 27/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import NoteTakerCore

class NotesTableViewController: UITableViewController {

    private let storage: NotesStorage
    
    init(storage: NotesStorage) {
        self.storage = storage
        
        super.init(style: .plain)
        
        self.title = "NoteTaker"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let disposeBag = DisposeBag()
    
    var notes = Variable<[Note]>([])
    
    var viewModels = [NoteViewModel]() {
        didSet {
            tableView.reloadData()
//            tableView.reloadData(withOldValue: oldValue, newValue: viewModels)
        }
    }
    
    private struct Constants {
        static let cellIdentifier = "note"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.cellIdentifier)
        
        storage.allNotes.asObservable()
            .observeOn(MainScheduler.instance)
            .bindTo(notes)
            .addDisposableTo(disposeBag)
        
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
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.cellIdentifier)
        
        cell?.accessoryType = .disclosureIndicator
        cell?.textLabel?.text = viewModels[indexPath.row].title
        
        return cell ?? UITableViewCell()
    }
    
}

