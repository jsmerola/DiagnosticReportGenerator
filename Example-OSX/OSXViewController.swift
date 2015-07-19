//
//  OSXViewController.swift
//  Example-OSX
//
//  Created by Jeff Merola on 7/18/15.
//  Copyright © 2015 Jeff Merola. All rights reserved.
//

import Cocoa
import WebKit

class OSXViewController: NSViewController {

    @IBOutlet weak var webView: WebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            let report = try DiagnosticReportGenerator().generateWithIdentifier(nil, extraInfo: nil)
            webView.mainFrame.loadHTMLString(report, baseURL: nil)
        } catch DiagnosticReportGenerator.ReportError.TemplateNotFound {
            print("Missing template file.")
        } catch DiagnosticReportGenerator.ReportError.TemplateParseError {
            print("Unable to read data from template file.")
        } catch {
            print("An error occurred.")
        }
    }

}

