//
//  SidebarViewController.swift
//  MarkEditMac
//
//  Created by Kevin Cline on 11/5/24.
//

import Cocoa
import MarkEditKit

class SidebarViewController: NSTabViewController {
  private(set) lazy var outlineViewController = {
    return SidebarOutlineViewController()
  }()

  private(set) lazy var statisticsViewController = {
    return SidebarStatisticsViewController()
  }()

  private let segmentedControl = NSSegmentedControl()
  private let controlOffset: CGFloat = 10
  private let segmentWidth: CGFloat = 64

  override func loadView() {

    let tabView = NSTabView()
    tabView.wantsLayer = true
    tabView.tabViewType = .noTabsNoBorder

    // set identifier for pane restoration
    tabView.identifier = NSUserInterfaceItemIdentifier("InspectorTabView")

    // cover the entire area with an NSVisualEffectView
    let view = NSVisualEffectView()
    view.material = .sidebar
    view.addSubview(tabView)

    tabView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: tabView.topAnchor),
      view.bottomAnchor.constraint(equalTo: tabView.bottomAnchor),
      view.leadingAnchor.constraint(equalTo: tabView.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: tabView.trailingAnchor),
    ])

    self.tabView = tabView

    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = false
    self.tabView.addSubview(self.segmentedControl)
    NSLayoutConstraint.activate([
      self.segmentedControl.topAnchor.constraint(equalTo: self.tabView.safeAreaLayoutGuide.topAnchor, constant: self.controlOffset),
      self.segmentedControl.centerXAnchor.constraint(equalTo: self.tabView.safeAreaLayoutGuide.centerXAnchor),
      self.segmentedControl.leadingAnchor.constraint(greaterThanOrEqualToSystemSpacingAfter: self.tabView.safeAreaLayoutGuide.leadingAnchor, multiplier: 1),
      self.segmentedControl.trailingAnchor.constraint(lessThanOrEqualToSystemSpacingAfter: self.tabView.safeAreaLayoutGuide.trailingAnchor, multiplier: 1),
    ])

    // self.segmentedControl.cell?.isBordered = false
    self.segmentedControl.segmentStyle = .capsule
    self.segmentedControl.target = self.tabView
    self.segmentedControl.action = #selector(tabView.takeSelectedTabViewItemFromSender)

    self.view = view
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let outlineViewTabItem = NSTabViewItem(viewController: outlineViewController)
    outlineViewTabItem.label = Localized.Toolbar.tableOfContents
    outlineViewTabItem.image = NSImage(systemSymbolName: Icons.listBulletRectangle, accessibilityDescription: Localized.Toolbar.tableOfContents)
    let statisticsViewTabItem = NSTabViewItem(viewController: statisticsViewController)
    statisticsViewTabItem.label = Localized.Toolbar.statistics
    statisticsViewTabItem.image = NSImage(systemSymbolName: Icons.chartPie, accessibilityDescription: Localized.Toolbar.statistics)

    self.addTabViewItem(outlineViewTabItem)
    self.addTabViewItem(statisticsViewTabItem)

    rebuildSegmentedControl()

    self.tabView.selectFirstTabViewItem(self)
    self.segmentedControl.selectedSegment = self.selectedTabViewItemIndex
  }

  func updateDocumentData(sourceText: String, fileURL: URL?, mainTitle: String, headings: [HeadingInfo]?) {
    outlineViewController.setHeadings(headings: headings)
    statisticsViewController.updateStatistics(sourceText: sourceText, fileURL: fileURL, mainTitle: mainTitle)
  }

  // MARK: Tab View Methods

  private var contentRect: NSRect {
    // take off control space
    let controlHeight = self.segmentedControl.frame.height + self.controlOffset
    let offset = self.tabView.safeAreaInsets.top + controlHeight + 1  // +1 for border

    var rect = self.tabView.bounds
    rect.origin.y = offset
    rect.size.height -= offset

    return rect
  }

  override func viewDidLayout() {
    super.viewDidLayout()

    self.tabView.selectedTabViewItem?.view?.frame = self.contentRect
  }

  override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
    super.tabView(tabView, didSelect: tabViewItem)

    self.segmentedControl.selectedSegment = self.selectedTabViewItemIndex
    self.tabView.selectedTabViewItem?.view?.frame = self.contentRect
  }

  /// Updates the private control every time when the line-up of tab items changed.
  private func rebuildSegmentedControl() {

    self.segmentedControl.segmentCount = self.tabView.numberOfTabViewItems

    for (segment, item) in self.tabView.tabViewItems.enumerated() {
      // self.segmentedControl.setLabel(item.label, forSegment: segment)
      self.segmentedControl.setImage(item.image, forSegment: segment)
      self.segmentedControl.setToolTip(item.label, forSegment: segment)
    }
  }
}
