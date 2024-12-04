//
//  Notification+Extension.swift
//
//  Created by cyan on 1/30/23.
//

import Foundation

public extension Notification.Name {
  static let fontSizeChanged = Self("fontSizeChanged")
  static let headingSelected = Self("headingSelected")
}

extension NotificationCenter {
  var fontSizePublisher: NotificationCenter.Publisher {
    publisher(for: .fontSizeChanged)
  }
}
