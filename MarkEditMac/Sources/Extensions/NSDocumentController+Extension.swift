//
//  NSDocumentController+Extension.swift
//  MarkEditMac
//
//  Created by cyan on 2024/10/14.
//

import AppKit
import MarkEditKit

extension NSDocumentController {
  /**
   Force the override of the last root directory for NSOpenPanel and NSSavePanel.
   */
  func setOpenPanelDirectory(_ directory: String) {
    UserDefaults.standard.setValue(directory, forKey: NSNavLastRootDirectory)
  }
}