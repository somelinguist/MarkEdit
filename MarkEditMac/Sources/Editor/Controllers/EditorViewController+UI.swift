//
//  EditorViewController+UI.swift
//  MarkEditMac
//
//  Created by cyan on 12/27/22.
//

import AppKit
import WebKit
import MarkEditKit
import Statistics

extension EditorViewController {
  func setUp() {
    splitView.isVertical = true
    splitView.dividerStyle = .thin
    splitView.identifier = NSUserInterfaceItemIdentifier("EditorSplitView")
    splitView.autosaveName = "EditorSplitViewAutoSave"

    let mainViewItem = NSSplitViewItem(viewController: mainViewController)
    mainViewItem.allowsFullHeightLayout = true
    addSplitViewItem(mainViewItem)

    let sideBarItem = NSSplitViewItem(inspectorWithViewController: sideBarViewController)
    sideBarItem.titlebarSeparatorStyle = .shadow
    sideBarItem.minimumThickness = 200
    sideBarItem.maximumThickness = 400
    sideBarItem.canCollapse = true
    sideBarItem.isCollapsed = false
    addSplitViewItem(sideBarItem)

    mainViewController.view.addSubview(replacePanel) // ReplacePanel must go before FindPanel
    mainViewController.view.addSubview(findPanel)
    mainViewController.view.addSubview(panelDivider)
    mainViewController.view.addSubview(webView)
    mainViewController.view.addSubview(statusView)

    if !hasFinishedLoading {
      mainViewController.view.addSubview(loadingIndicator)
    }

    layoutPanels()
    layoutWebView()
    layoutLoadingIndicator()
    layoutStatusView()

    // Initially hide panels to prevent being found by VoiceOver
    findPanel.isHidden = true
    replacePanel.isHidden = true

    // Trigger an additional layout loop to correct view (find panels) positions
    safeAreaObservation = view.observe(\.safeAreaInsets) { view, _ in
      Task { @MainActor in
        view.needsLayout = true
      }
    }

    // Track popovers that use editor as the positioning container
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(popoverDidShow(_:)),
      name: NSPopover.didShowNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(selectedHeadingDidChange(_:)),
      name: .headingSelected,
      object: nil
    )

    addLocalMonitorForEvents()
  }

  func configureToolbar() {
    let toolbar = NSToolbar(identifier: "EditorToolbar")
    toolbar.displayMode = .iconOnly
    toolbar.delegate = self
    toolbar.allowsUserCustomization = true
    toolbar.autosavesConfiguration = true

    view.window?.toolbar = toolbar
    view.window?.toolbar?.validateVisibleItems()

    view.window?.acceptsMouseMovedEvents = true
    view.window?.appearance = AppTheme.current.resolvedAppearance

    updateWindowColors(.current)
  }

  func updateWindowColors(_ theme: AppTheme) {
    let backgroundColor = webBackgroundColor ?? theme.windowBackground
    view.window?.backgroundColor = backgroundColor
    view.window?.toolbarEffectView?.layerBackgroundColor = backgroundColor

    let prefersTintedToolbar = theme.prefersTintedToolbar
    (view.window as? EditorWindow)?.prefersTintedToolbar = prefersTintedToolbar

    statusView.setBackgroundColor(backgroundColor)
    findPanel.setBackgroundColor(backgroundColor)
    replacePanel.setBackgroundColor(backgroundColor)
  }

  @available(macOS 15.1, *)
  func updateWritingTools(isActive: Bool) {
    let performUpdate = {
      // Ignore beforeInput handling to work around undo stack issues
      self.bridge.writingTools.setActive(
        isActive: isActive,
        reselect: MarkEditWritingTools.shouldReselect(with: MarkEditWritingTools.requestedTool)
      )

      // Invisible rendering doesn't work well with WritingTools, temporarily disable it for now
      self.setInvisiblesBehavior(behavior: isActive ? .never : AppPreferences.Editor.invisiblesBehavior)
    }

    if isActive {
      performUpdate()
    } else {
      DispatchQueue.main.asyncAfter(
        deadline: .now() + 0.2,
        execute: performUpdate
      )
    }
  }

  func layoutPanels(animated: Bool = false) {
    findPanel.update(animated).frame = CGRect(
      x: 0,
      y: contentHeight - (findPanel.mode == .hidden ? 0 : findPanel.frame.height),
      width: mainViewController.view.bounds.width,
      height: findPanel.frame.height
    )

    replacePanel.update(animated).frame = CGRect(
      x: findPanel.frame.minX,
      y: findPanel.frame.minY - (findPanel.mode == .replace ? replacePanel.frame.height : 0),
      width: findPanel.frame.width,
      height: findPanel.frame.height - findPanel.searchField.frame.minY
    )

    replacePanel.layoutInfo = (findPanel.searchField.frame, findPanel.findButtons.frame.height)
    panelDivider.update(animated).frame = CGRect(x: 0, y: (findPanel.mode == .replace ? replacePanel : findPanel).frame.minY, width: mainViewController.view.frame.width, height: panelDivider.length)
  }

  func layoutWebView(animated: Bool = false) {
    // Move the view instead of changing its height,
    // because resizing would introduce unnecessary updates,
    // which results in sluggish animation.
    let height = contentHeight
    let offset = panelDivider.frame.minY - height

    webView.update(animated).frame = CGRect(
      x: 0,
      y: offset,
      width: mainViewController.view.bounds.width,
      height: height
    )
  }

  func layoutLoadingIndicator() {
    guard !loadingIndicator.hasUnfinishedAnimations else {
      return
    }

    let size: Double = 72
    loadingIndicator.frame = CGRect(
      x: (mainViewController.view.bounds.width - size) * 0.5,
      y: (mainViewController.view.bounds.height - size) * 0.5,
      width: size,
      height: size
    )

    // Hide the indicator when the window is small enough
    loadingIndicator.isHidden = mainViewController.view.bounds.width < 200 || mainViewController.view.bounds.height < 200
  }

  func updateSidebar() {

    Task {
      let tableOfContents = await tableOfContents

      let (sourceText, fileURL, mainTitle) = await {
        let selectedText = (try? await bridge.selection.getText()) ?? ""
        let mainTitle = Localized.Toolbar.statistics

        return (
          selectedText.isEmpty ? (await editorText ?? "") : selectedText,
          selectedText.isEmpty ? document?.fileURL : nil,
          selectedText.isEmpty ? mainTitle : "\(mainTitle) (\(Localized.Settings.selection))"
        )
      }()

      sideBarViewController.updateDocumentData(sourceText: sourceText, fileURL: fileURL, mainTitle: mainTitle, headings: tableOfContents)
    }
  }

  func layoutStatusView() {
    statusView.frame = CGRect(
      x: mainViewController.view.bounds.width - statusView.frame.width - 6,
      y: bottomPanelHeight + 8, // Vertical margins are intentionally larger to visually look the same
      width: statusView.frame.width,
      height: statusView.frame.height
    )

    mainViewController.view.mirrorImmediateSubviewIfNeeded(statusView)
  }

  func handleMouseMoved(_ event: NSEvent) {
    guard view.window?.isKeyWindow == true else {
      return
    }

    // WKWebView contentEditable keeps showing i-beam, fix that
    if NSCursor.current != NSCursor.arrow {
      let location = event.locationInWindow.y
      if location > contentHeight && location < mainViewController.view.frame.height {
        NSCursor.arrow.push()
      }
    }

    let trackingRect = {
      var bounds = view.bounds
      bounds.size.height = contentHeight - findPanelHeight
      return bounds
    }()

    // WebKit doesn't update hover state reliably, e.g., "mouseup" outside the window,
    // propagate a native event to help update the UI.
    let mouseExitedWindow = !trackingRect.contains(event.locationInWindow)
    if mouseExitedWindow != self.mouseExitedWindow && AppPreferences.Editor.showLineNumbers {
      let clientX = event.locationInWindow.x
      let clientY = event.locationInWindow.y

      if mouseExitedWindow {
        bridge.core.handleMouseExited(clientX: clientX, clientY: clientY)
      }

      self.mouseExitedWindow = mouseExitedWindow
    }
  }

  func startTextEditing() {
    view.window?.makeFirstResponder(webView)
  }

  func refreshEditFocus() {
    startTextEditing()
    bridge.selection.refreshEditFocus()
  }

  func resignFindPanelFocus() {
    guard isFindPanelFirstResponder else {
      return
    }

    startTextEditing()
  }

  func removeFloatingUIElements() {
    if completionContext.isPanelVisible {
      cancelCompletion()
    }

    NSSpellChecker.shared.declineCorrectionIndicator(for: webView)
    presentedPopover?.close()
  }

  @discardableResult
  func removePresentedPopovers(contentClass: AnyClass) -> Bool {
    guard let presented = presentedViewControllers?.filter({ $0.isKind(of: contentClass) }) else {
      return false
    }

    guard !presented.isEmpty else {
      return false
    }

    presented.forEach { dismiss($0) }
    return true
  }

  func resetUserDefinedMenuItems() {
    guard let menu = NSApp.appDelegate?.mainExtensionsMenu else {
      return Logger.assertFail("Missing main extensions menu")
    }

    // Remove existing ones, always recreate a new item
    (menu.items.filter {
      $0.identifier?.rawValue.hasPrefix(EditorMenuItem.uniquePrefix) == true
    }).forEach {
      menu.removeItem($0)
    }

    for spec in userDefinedMenuItems {
      let item = createMenuItem(spec: spec.item, handler: bridge.ui.handleMainMenuAction)
      item.identifier = NSUserInterfaceItemIdentifier("\(EditorMenuItem.uniquePrefix).\(spec.id)")

      // Preferably, make it the last one before the special divider
      if let index = (menu.items.firstIndex { $0.identifier?.rawValue == EditorMenuItem.specialDivider }) {
        menu.insertItem(item, at: index)
      } else {
        menu.addItem(item)
      }
    }
  }

  // MARK: - Exposed to user scripts

  func addMainMenuItems(items: [(id: String, item: WebMenuItem)]) {
    userDefinedMenuItems.removeAll { old in
      items.contains { new in old.id == new.id }
    }

    userDefinedMenuItems.append(contentsOf: items.map {
      EditorMenuItem(id: $0.id, item: $0.item)
    })

    resetUserDefinedMenuItems()
  }

  func showContextMenu(items: [WebMenuItem], location: CGPoint) {
    let menu = createMenu(items: items, handler: bridge.ui.handleContextMenuAction)
    menu.identifier = EditorWebView.userDefinedContextMenuID

    NSCursor.arrow.push()
    menu.popUp(positioning: nil, at: location, in: webView)
  }

  func showAlert(title: String?, message: String?, buttons: [String]?) -> NSApplication.ModalResponse {
    let alert = NSAlert()
    alert.messageText = title ?? ""
    alert.informativeText = message ?? ""

    buttons?.forEach {
      alert.addButton(withTitle: $0)
    }

    return alert.runModal()
  }

  func showTextBox(title: String?, placeholder: String?, defaultValue: String?) -> String? {
    let alert = NSAlert()
    alert.messageText = title ?? ""
    alert.addButton(withTitle: Localized.General.done)
    alert.addButton(withTitle: Localized.General.cancel)

    let textField = NSTextField(frame: CGRect(x: 0, y: 0, width: 256, height: 22))
    textField.placeholderString = placeholder
    textField.stringValue = defaultValue ?? ""
    alert.accessoryView = textField

    return alert.runModal() == .alertFirstButtonReturn ? textField.stringValue : nil
  }
}

// MARK: - Private

private extension EditorViewController {
  var contentHeight: Double {
    view.bounds.height - view.safeAreaInsets.top
  }

  var findPanelHeight: Double {
    findPanel.isHidden ? 0 : findPanel.frame.height
  }

  @objc func popoverDidShow(_ notification: Notification) {
    guard let popover = notification.object as? NSPopover else {
      return
    }

    guard popover.sourceView?.belongs(to: view) == true else {
      return
    }

    presentedPopover = popover
  }

  func createMenuItem(
    spec: WebMenuItem,
    handler: @escaping (String, ((Result<Void, WKWebView.InvokeError>) -> Void)?) -> Void
  ) -> NSMenuItem {
    if spec.separator {
      return .separator()
    } else if let children = spec.children {
      let item = NSMenuItem(title: spec.title ?? "")
      item.submenu = createMenu(items: children, handler: handler)
      return item
    } else if let title = spec.title {
      let item = NSMenuItem(title: title)
      if let actionID = spec.actionID {
        item.addAction { handler(actionID, nil) }
      }

      item.keyEquivalent = spec.key ?? ""
      item.keyEquivalentModifierMask = .init(stringValues: spec.modifiers ?? [])
      return item
    } else {
      Logger.assertFail("Invalid spec of menu item: \(spec)")
      return NSMenuItem()
    }
  }

  func createMenu(
    items: [WebMenuItem],
    handler: @escaping (String, ((Result<Void, WKWebView.InvokeError>) -> Void)?) -> Void
  ) -> NSMenu {
    let menu = NSMenu()
    items.map { createMenuItem(spec: $0, handler: handler) }.forEach {
      menu.addItem($0)
    }

    return menu
  }
}
