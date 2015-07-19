//
//  ViewController.swift
//  Example
//
//  Created by Jeff Merola on 7/18/15.
//  Copyright © 2015 Jeff Merola. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var webView: UIWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let additionalInformation: [String: AnyObject] = [
            "<Additional Info>": "Can supply extra info"
        ]
        
        do {
            let report = try DiagnosticReportGenerator().generateWithIdentifier("SOME_CUSTOM_IDENTIFIER", extraInfo: additionalInformation, includeDefaults: false)
            webView.loadHTMLString(report, baseURL: nil)
        } catch DiagnosticReportGenerator.ReportError.TemplateNotFound {
            print("Missing template file.")
        } catch DiagnosticReportGenerator.ReportError.TemplateParseError {
            print("Unable to read data from template file.")
        } catch {
            print("An error occurred.")
        }
    }

}

