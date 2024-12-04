//
//  SidebarStatisticsViewController.swift
//  MarkEditMac
//
//  Created by Kevin Cline on 11/5/24.
//

import Cocoa
import Statistics

class SidebarStatisticsViewController: NSViewController {

  private var statisticsController: StatisticsController?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.wantsLayer = true
  }

  override func viewDidLayout() {
    super.viewDidLayout()

    if let statisticsController = statisticsController {
      statisticsController.view.frame = view.bounds
    }
  }

  func updateStatistics(sourceText: String, fileURL: URL?, mainTitle: String) {
    view.subviews.removeAll()

    statisticsController = StatisticsController(
      sourceText: sourceText,
      fileURL: fileURL,
      localizable: StatisticsLocalizable(
        mainTitle: mainTitle,
        characters: Localized.Statistics.characters,
        words: Localized.Statistics.words,
        sentences: Localized.Statistics.sentences,
        paragraphs: Localized.Statistics.paragraphs,
        readTime: Localized.Statistics.readTime,
        fileSize: Localized.Statistics.fileSize
      )
    )

    if let statisticsController = statisticsController {
      statisticsController.view.frame = view.bounds
      view.addSubview(statisticsController.view)
    }
  }
}
