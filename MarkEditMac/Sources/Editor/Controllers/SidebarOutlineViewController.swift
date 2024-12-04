//
//  SidebarOutlineViewController.swift
//  MarkEditMac
//
//  Created by Kevin Cline on 11/5/24.
//

import Cocoa

import MarkEditKit

class SidebarOutlineViewController: NSViewController {
  private var headings: [HeadingInfo] = []

  private var scrollView = NSScrollView(frame: .zero)
  private var tableView = NSTableView()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.wantsLayer = true
    view.layerBackgroundColor = .clear

    tableView.backgroundColor = NSColor.clear
    tableView.dataSource = self
    tableView.delegate = self
    tableView.headerView = nil
    tableView.style = .sourceList

    tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "TitleColumn")))

    scrollView.drawsBackground = false
    scrollView.documentView = tableView

    view.addSubview(scrollView)

    scrollView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: scrollView.topAnchor),
      view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
    ])

    tableView.target = self
    tableView.action = #selector(tableViewDidClick)
  }

  func setHeadings(headings: [HeadingInfo]?) {
    if let headings {
      self.headings = headings
    } else {
      self.headings = []
    }
    tableView.reloadData()
    tableView.noteNumberOfRowsChanged()
  }
}

extension SidebarOutlineViewController: NSTableViewDelegate, NSTableViewDataSource {

  func numberOfRows(in aTableView: NSTableView) -> Int {
    return headings.count
  }

  func makeCellView() -> NSTableCellView {
    let cellView = NSTableCellView()
    cellView.identifier = NSUserInterfaceItemIdentifier(rawValue: "TitleColumn")
    let textField = NSTextField()
    textField.isEditable = false
    textField.isBezeled = false
    textField.drawsBackground = false
    textField.autoresizingMask = [.width, .height]
//    textField.translatesAutoresizingMaskIntoConstraints = false
    cellView.addSubview(textField)
    cellView.textField = textField
    return cellView
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

    let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "TitleColumn"), owner: self) as? NSTableCellView ?? makeCellView()

    let info = headings[row]
    let title = info.title.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? info.title.trimmingCharacters(in: .whitespaces)
    let fontSize = NSFont.systemFontSize(for: .regular)
    let attributedTitle = NSMutableAttributedString()

//    attributedTitle.append(NSAttributedString(string: info.selected ? "‣" : " ", attributes: [
//      .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium),
//    ]))

    let prefix = String(repeating: "#", count: info.level)
    attributedTitle.append(NSAttributedString(string: "\(prefix)", attributes: [
      .font: NSFont.systemFont(ofSize: fontSize - 1, weight: .regular),
      .foregroundColor: NSColor.lightGray.withAlphaComponent(0.7),
      .baselineOffset: -4.0,
    ]))

    attributedTitle.append(NSAttributedString(string: " \(title)", attributes: [
      .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
      .baselineOffset: -4.0,
    ]))

    cellView.textField?.attributedStringValue = attributedTitle

    if info.selected {
      tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
    return cellView
  }

  @objc func tableViewDidClick() {
    let headingInfo = headings[tableView.clickedRow]
    NotificationCenter.default.post(
      name: .headingSelected,
      object: headingInfo
    )
  }
}
