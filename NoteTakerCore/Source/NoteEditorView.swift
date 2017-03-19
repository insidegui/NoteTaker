//
//  NoteEditorView.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 27/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

#if os(macOS)
    import Cocoa
    
    public typealias UIView = NSView
#else
    import UIKit
#endif

import WebKit

public protocol NoteEditorViewDelegate: class {
    func noteEditorView(_ sender: NoteEditorView, contentsDidChange contents: String)
}

public final class NoteEditorView: UIView {

    public weak var delegate: NoteEditorViewDelegate?
    
    public fileprivate(set) var currentContents: String = ""
    
    public func setContents(_ contents: String) {
        loadEditor(with: contents)
    }
    
    fileprivate var webViewIsSettingContents = false
    
    #if os(macOS)
    
    public override var isFlipped: Bool {
        return true
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setup()
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return webView.acceptsFirstMouse(for: event)
    }
    
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    public override var canBecomeKeyView: Bool {
        return true
    }
    
    #else
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setup()
    }
    
    #endif
    
    public override func becomeFirstResponder() -> Bool {
        return webView.becomeFirstResponder()
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        
        setup()
    }
    
    private var setupDone = false
    
    private func setup() {
        guard !setupDone else { return }
        setupDone = true
        
        #if os(macOS)
            wantsLayer = true
            layer?.backgroundColor = NSColor.white.cgColor
        #else
            backgroundColor = .white
        #endif
        
        webView.frame = bounds
        addSubview(webView)
    }
    
    private lazy var webView: WKWebView = {
        let v = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        
        #if os(macOS)
            v.autoresizingMask = [.viewHeightSizable, .viewWidthSizable]
        #else
            v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        #endif
        
        v.configuration.userContentController.add(self, name: "editor")
        
        return v
    }()
    
    private lazy var editorSource: String? = {
        guard let editorSourceFile = Bundle(for: NoteEditorView.self).url(forResource: "Editor", withExtension: "html") else { return nil }
        guard let editorSourceData = try? Data(contentsOf: editorSourceFile) else { return nil }
        
        return String(data: editorSourceData, encoding: .utf8)
    }()
    
    private func loadEditor(with contents: String = "") {
        guard let editorSource = editorSource else { return }
        
        webView.loadHTMLString(editorSource.replacingOccurrences(of: "{BODY}", with: contents), baseURL: nil)
    }
    
}

private enum WebViewMessages: String {
    case loaded
    case input
}

extension NoteEditorView: WKScriptMessageHandler {
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let inputStr = message.body as? String else { return }
        
        DispatchQueue.main.async {
            self.currentContents = inputStr
            
            self.delegate?.noteEditorView(self, contentsDidChange: inputStr)
        }
    }
    
}
