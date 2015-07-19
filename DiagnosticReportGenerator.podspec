Pod::Spec.new do |s|
  s.name         = "DiagnosticReportGenerator"
  s.version      = "1.0.0"
  s.summary      = "Simple diagnostic report generator"
  s.description  = <<-DESC
                   Easily create a diagnostic report to attach to bug report emails in your apps.
				   
				   Includes information like:
				   * Device model
				   * Battery state
				   * Disk space
				   * Version info
				   * User Defaults
				   * and more...
                   DESC
  s.homepage     = "https://github.com/jsmerola/DiagnosticReportGenerator"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Jeff Merola" => "jeffrey.merola@gmail.com" }
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.source       = { :git => "https://github.com/jsmerola/DiagnosticReportGenerator.git", :tag => "1.0.0" }
  s.source_files  = 'DiagnosticReportGenerator/DiagnosticReportGenerator.swift'
  s.resource  = "DiagnosticReportGenerator/DiagnosticReportTemplate.html"
  s.requires_arc = true
end