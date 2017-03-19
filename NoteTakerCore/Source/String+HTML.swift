//
//  String+HTML.swift
//  NoteTaker
//
//  Created by Guilherme Rambo on 12/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

extension String {
    
    var parsingHTML: NSAttributedString {
        let attrs: [String: Any] = [
            NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
            NSCharacterEncodingDocumentAttribute: String.Encoding.utf8
        ]
        
        return NSAttributedString(string: self, attributes: attrs)
    }
    
    var removingHTML: String {
        return replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                .replacingOccurrences(of: "&[^\\s]*;", with: "", options: .regularExpression, range: nil)
    }
    
    var firstLine: String {
        return components(separatedBy: .newlines).first ?? self
    }
    
}
