//
//  PreferencesViewController.swift
//  Pock
//
//  Created by Pierluigi Galdi on 02/05/21.
//

import Cocoa

class PreferencesViewController: NSViewController {

    // MARK: UI Elements
	@IBOutlet private weak var versionLabel: NSTextField!
	
	/// General
	@IBOutlet private weak var generalTitleLabel: NSTextField!
	@IBOutlet private weak var allowBlankTouchBarCheckbox: NSButton!
	@IBOutlet private weak var allowBlankTouchBarDescriptionLabel: NSTextField!
	@IBOutlet private weak var launchAtLoginCheckbox: NSButton!
	
	/// Layout Styles
	@IBOutlet private weak var layoutStyleTitleLabel: NSTextField!
	@IBOutlet private weak var layoutStyleWithControlStripButton: NSButton!
	@IBOutlet private weak var layoutStyleWithControlStripLabel: NSTextField!
	@IBOutlet private weak var layoutStyleFullWidthButton: NSButton!
	@IBOutlet private weak var layoutStyleFullWidthLabel: NSTextField!
	
	/// Double `^ control` shortcut
	@IBOutlet private weak var doubleControlTitleLabel: NSTextField!
	@IBOutlet private weak var doubleControlDescriptionLabel: NSTextField!
	@IBOutlet private weak var defaultTouchBarPresentationModeLabel: NSTextField!
	@IBOutlet private weak var defaultTouchBarPresentationModePopUp: NSPopUpButton!
	@IBOutlet private weak var defaultTouchBarPresentationModeDesc: NSTextField!
	
	/// Cursor options
	@IBOutlet private weak var cursorOptionsTitleLabel: NSTextField!
	@IBOutlet private weak var enableMouseSupportCheckbox: NSButton!
	@IBOutlet private weak var showTrackingAreaCheckbox: NSButton!
	
	/// Update sections
	@IBOutlet private weak var checkForUpdatesOnceADayCheckbox: NSButton!
	@IBOutlet private weak var checkForUpdatesNowButton: NSButton!
    @IBOutlet private weak var checkForUpdatesSpinner: NSProgressIndicator!
	
	// MARK: Overrides
	
	override var title: String? {
		get {
			return "preferences.window.title".localized
		}
		set {
			view.window?.title = newValue ?? ""
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		configureUIElements()
		localizeUIElements()
		addModifierTouchBarSection()
		if AppController.shared.isVisible == false {
			AppController.shared.reload(shouldFetchLatestVersions: false)
		}
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		NSApp.activate(ignoringOtherApps: true)
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		shouldAskToupdate { [weak self] newVersion in
			if let self = self, let new = newVersion {
                self.checkForUpdatesNowButton.title = "preferences.updates.new-version-available.title".localized
                self.checkForUpdatesNowButton.bezelColor = .controlAccentColor
                self.showUpdateAlert(for: new)
			}
		}
	}
	
	override func viewWillDisappear() {
		super.viewWillDisappear()
		NSApp.deactivate()
	}
	
	deinit {
		Roger.debug("[Preferences][ViewController] - deinit")
	}
	
	// MARK: Configure UI Elements
	private func configureUIElements() {
		/// Checkboxes
		allowBlankTouchBarCheckbox.state = Preferences[.allowBlankTouchBar] == true ? .on : .off
		launchAtLoginCheckbox.state  = Preferences[.launchAtLogin] == true ? .on : .off
		enableMouseSupportCheckbox.state = Preferences[.mouseSupportEnabled] == true ? .on : .off
		showTrackingAreaCheckbox.state = Preferences[.showTrackingArea] == true ? .on : .off
		showTrackingAreaCheckbox.isEnabled = Preferences[.mouseSupportEnabled] == true
		checkForUpdatesOnceADayCheckbox.state = Preferences[.checkForUpdatesOnceADay] == true ? .on : .off
        checkForUpdatesSpinner.stopAnimation(nil)
        checkForUpdatesNowButton.bezelColor = .windowFrameColor
		/// Layout Style
		updateLayoutStyleUIElements()
		/// Default Touch Bar Presentation Mode
		updateDefaultPresentationModePopUpButton()
		/// Build info
		versionLabel.stringValue = Updater.fullAppVersion
	}
	
	private func localizeUIElements() {
		generalTitleLabel.stringValue = "preferences.general.title".localized
		allowBlankTouchBarCheckbox.title = "preferences.general.allow-blank-touchbar.title".localized
		allowBlankTouchBarDescriptionLabel.stringValue = "preferences.general.allow-blank-touchbar.desc".localized
		launchAtLoginCheckbox.title = "preferences.general.launch-at-login".localized
		
		layoutStyleTitleLabel.stringValue = "preferences.layout.title".localized
		
		doubleControlTitleLabel.stringValue = "preferences.double-control.title".localized
		doubleControlDescriptionLabel.stringValue = "preferences.double-control.desc".localized
		defaultTouchBarPresentationModeLabel.stringValue = "preferences.default-touchbar.shows".localized
		defaultTouchBarPresentationModeDesc.stringValue = "preferences.default-touchbar.desc".localized
		
		cursorOptionsTitleLabel.stringValue = "preferences.cursor-options.title".localized
		enableMouseSupportCheckbox.title = "preferences.cursor-options.enable-mouse-support".localized
		showTrackingAreaCheckbox.title = "preferences.cursor-options.show-tracking-area".localized
		
		checkForUpdatesOnceADayCheckbox.title = "preferences.updates.check-for-updates-once-a-day".localized
		checkForUpdatesNowButton.title = "general.action.check-for-updates".localized
	}
	
	private func updateDefaultPresentationModePopUpButton() {
		let mode: PresentationMode = Preferences[.userDefinedPresentationMode]
		defaultTouchBarPresentationModePopUp.removeAllItems()
		defaultTouchBarPresentationModePopUp.addItems(withTitles: PresentationMode.allCases.compactMap({ $0.title }))
		defaultTouchBarPresentationModePopUp.selectItem(withTitle: mode.title)
	}
	
	private func updateLayoutStyleUIElements() {
		func resizeButton(_ button: NSButton, minify: Bool) {
			if let constraint = button.constraints.first(where: { $0.identifier == "layout-style.option.width" }) {
				NSAnimationContext.runAnimationGroup { context in
					context.duration = 0.2725
					context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
					constraint.animator().constant = minify ? 140 : 280
					button.superview?.animator().alphaValue = minify ? 0.525 : 1.0
				}
			}
		}
		let style: LayoutStyle = Preferences[.layoutStyle]
		switch style {
		case .withControlStrip:
			resizeButton(layoutStyleWithControlStripButton, minify: false)
			resizeButton(layoutStyleFullWidthButton, minify: true)
		case .fullWidth:
			resizeButton(layoutStyleWithControlStripButton, minify: true)
			resizeButton(layoutStyleFullWidthButton, minify: false)
		}
	}
	
	// MARK: Actions
	
	@IBAction private func didChangeLayoutStyle(for button: NSButton) {
		let style: LayoutStyle
		switch button {
		case layoutStyleWithControlStripButton:
			style = .withControlStrip
		case layoutStyleFullWidthButton:
			style = .fullWidth
		default:
			return
		}
		guard Preferences[.layoutStyle] != style else {
			return
		}
		Preferences[.layoutStyle] = style.rawValue
		updateLayoutStyleUIElements()
		async(after: 0.4) {
			NotificationCenter.default.post(name: .shouldReloadPock, object: nil)
		}
	}
	
	@IBAction private func didChangeDefaultTouchBarPresentationMode(_ button: NSPopUpButton) {
		let presentationMode = PresentationMode.allCases.without(.undefined)[defaultTouchBarPresentationModePopUp.indexOfSelectedItem]
		if Preferences[.userDefinedPresentationMode] as PresentationMode != presentationMode {
			Preferences[.userDefinedPresentationMode] = presentationMode.rawValue
			if AppController.shared.pockTouchBarController?.isVisible == nil || false {
				TouchBarHelper.setPresentationMode(to: presentationMode)
			}
		}
	}
	
	@IBAction private func didChangePreferencesOption(for button: NSButton) {
		let key: Preferences.Keys
		var shouldReloadPock: Bool = true
		let newValue = button.state == .on
		switch button {
		case allowBlankTouchBarCheckbox:
			key = .allowBlankTouchBar
		
		case launchAtLoginCheckbox:
			key = .launchAtLogin
			shouldReloadPock = false
		
		case enableMouseSupportCheckbox:
			key = .mouseSupportEnabled
			showTrackingAreaCheckbox.isEnabled = newValue
		
		case showTrackingAreaCheckbox:
			key = .showTrackingArea
		
		case checkForUpdatesOnceADayCheckbox:
			key = .checkForUpdatesOnceADay
			shouldReloadPock = false
			
		default:
			return
		}
		Preferences[key] = newValue
		if shouldReloadPock {
			async {
				NotificationCenter.default.post(name: .shouldReloadPock, object: nil)
			}
		}
		if button == checkForUpdatesOnceADayCheckbox {
			async {
				NotificationCenter.default.post(name: .shouldEnableAutomaticUpdates, object: nil)
			}
		}
	}
	
	// MARK: Modifier Touch Bars

	/// Built in code and inserted after the double `⌃ Control` section of the right column.
	private func addModifierTouchBarSection() {
		guard let doubleControlSection = doubleControlTitleLabel.superview?.superview,
			  let column = doubleControlSection.superview as? NSStackView,
			  let index = column.arrangedSubviews.firstIndex(of: doubleControlSection) else {
			return
		}
		let title = NSTextField(labelWithString: "preferences.modifier-bars.title".localized)
		let description = NSTextField(wrappingLabelWithString: "preferences.modifier-bars.desc".localized)
		description.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
		description.textColor = .secondaryLabelColor
		description.preferredMaxLayoutWidth = 440
		let checkboxes: [NSView] = ModifierTouchBarMode.allCases.enumerated().map { index, mode in
			let checkbox = NSButton(checkboxWithTitle: "preferences.modifier-bars.\(mode.modifierName)".localized,
									target: self, action: #selector(didChangeModifierTouchBarOption(_:)))
			checkbox.tag = index
			checkbox.state = Preferences[mode.preferenceKey] == true ? .on : .off
			return checkbox
		}
		let section = NSStackView(views: [title, description] + checkboxes)
		section.orientation = .vertical
		section.alignment = .leading
		section.spacing = 6
		section.setCustomSpacing(10, after: description)
		let separator = NSBox()
		separator.boxType = .separator
		column.insertArrangedSubview(separator, at: index + 1)
		column.insertArrangedSubview(section, at: index + 2)
		separator.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
		addAppControlsSection(to: column, at: index + 3)
	}

	// MARK: App Controls

	private func addAppControlsSection(to column: NSStackView, at index: Int) {
		let title = NSTextField(labelWithString: "preferences.app-controls.title".localized)
		let description = NSTextField(wrappingLabelWithString: "preferences.app-controls.desc".localized)
		description.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
		description.textColor = .secondaryLabelColor
		description.preferredMaxLayoutWidth = 440
		let disabled = AppControlsTouchBarItem.disabledProfiles
		var seen = Set<String>()
		let profiles = AppControlsTouchBarItem.allProfiles.filter { seen.insert($0.id).inserted }
		let checkboxes: [NSView] = profiles.map { profile in
			let checkbox = NSButton(checkboxWithTitle: profile.name, target: self, action: #selector(didChangeAppProfile(_:)))
			checkbox.identifier = NSUserInterfaceItemIdentifier(profile.id)
			checkbox.state = disabled.contains(profile.id) ? .off : .on
			checkbox.toolTip = profile.actions.map(\.title).joined(separator: ", ")
			return checkbox
		}
		let grid = NSStackView(views: [
			NSStackView(views: Array(checkboxes.prefix((checkboxes.count + 1) / 2))),
			NSStackView(views: Array(checkboxes.dropFirst((checkboxes.count + 1) / 2)))
		])
		grid.orientation = .horizontal
		grid.alignment = .top
		grid.spacing = 24
		grid.arrangedSubviews.compactMap { $0 as? NSStackView }.forEach {
			$0.orientation = .vertical
			$0.alignment = .leading
			$0.spacing = 4
		}
		let customize = NSButton(title: "preferences.app-controls.customize".localized, target: self, action: #selector(openCustomAppProfiles))
		customize.bezelStyle = .rounded
		let section = NSStackView(views: [title, description, grid, customize])
		section.orientation = .vertical
		section.alignment = .leading
		section.spacing = 6
		section.setCustomSpacing(10, after: description)
		section.setCustomSpacing(10, after: grid)
		let separator = NSBox()
		separator.boxType = .separator
		column.insertArrangedSubview(separator, at: index)
		column.insertArrangedSubview(section, at: index + 1)
		separator.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
		addNativeTouchBarAppsSection(to: column, at: index + 2)
	}

	// MARK: Native app Touch Bars

	private let nativeAppsList = NSStackView()

	private func addNativeTouchBarAppsSection(to column: NSStackView, at index: Int) {
		let title = NSTextField(labelWithString: "preferences.native-apps.title".localized)
		let description = NSTextField(wrappingLabelWithString: "preferences.native-apps.desc".localized)
		description.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
		description.textColor = .secondaryLabelColor
		description.preferredMaxLayoutWidth = 440
		nativeAppsList.orientation = .vertical
		nativeAppsList.alignment = .leading
		nativeAppsList.spacing = 4
		reloadNativeAppsList()
		let add = NSButton(title: "preferences.native-apps.add".localized, target: self, action: #selector(addNativeTouchBarApp))
		add.bezelStyle = .rounded
		let section = NSStackView(views: [title, description, nativeAppsList, add])
		section.orientation = .vertical
		section.alignment = .leading
		section.spacing = 6
		section.setCustomSpacing(10, after: description)
		section.setCustomSpacing(10, after: nativeAppsList)
		let separator = NSBox()
		separator.boxType = .separator
		column.insertArrangedSubview(separator, at: index)
		column.insertArrangedSubview(section, at: index + 1)
		separator.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
		addControlsSection(to: column, at: index + 2)
	}

	// MARK: Controls

	private let focusShortcutField = NSTextField()

	private func addControlsSection(to column: NSStackView, at index: Int) {
		let title = NSTextField(labelWithString: "preferences.controls.title".localized)
		let description = NSTextField(wrappingLabelWithString: "preferences.controls.desc".localized)
		description.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
		description.textColor = .secondaryLabelColor
		description.preferredMaxLayoutWidth = 440
		let enabled = ControlsButton.enabled
		let checkboxes: [NSView] = ControlsButton.allCases.map { control in
			let checkbox = NSButton(checkboxWithTitle: control.title, target: self, action: #selector(didChangeControlsButton(_:)))
			checkbox.identifier = NSUserInterfaceItemIdentifier(control.rawValue)
			checkbox.state = enabled.contains(control) ? .on : .off
			return checkbox
		}
		let half = (checkboxes.count + 1) / 2
		let grid = NSStackView(views: [NSStackView(views: Array(checkboxes.prefix(half))), NSStackView(views: Array(checkboxes.dropFirst(half)))])
		grid.orientation = .horizontal
		grid.alignment = .top
		grid.spacing = 24
		grid.arrangedSubviews.compactMap { $0 as? NSStackView }.forEach {
			$0.orientation = .vertical
			$0.alignment = .leading
			$0.spacing = 4
		}
		focusShortcutField.stringValue = Preferences[.focusShortcutName]
		focusShortcutField.placeholderString = "Toggle Focus"
		focusShortcutField.target = self
		focusShortcutField.action = #selector(didChangeFocusShortcut(_:))
		focusShortcutField.widthAnchor.constraint(equalToConstant: 180).isActive = true
		let focusRow = NSStackView(views: [NSTextField(labelWithString: "preferences.controls.focus-shortcut".localized), focusShortcutField])
		focusRow.spacing = 8
		let section = NSStackView(views: [title, description, grid, focusRow])
		section.orientation = .vertical
		section.alignment = .leading
		section.spacing = 6
		section.setCustomSpacing(10, after: description)
		section.setCustomSpacing(10, after: grid)
		let separator = NSBox()
		separator.boxType = .separator
		column.insertArrangedSubview(separator, at: index)
		column.insertArrangedSubview(section, at: index + 1)
		separator.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
		addStatusSection(to: column, at: index + 2)
	}

	// MARK: Status

	private let statusFormatField = NSTextField()
	private static let statusOptions: [(Preferences.Keys, String)] = [
		(.shouldShowLangItem, "preferences.status.input-source"),
		(.shouldShowWifiItem, "preferences.status.wifi"),
		(.shouldShowPowerItem, "preferences.status.battery"),
		(.shouldShowBatteryIcon, "preferences.status.battery-icon"),
		(.shouldShowBatteryPercentage, "preferences.status.battery-percentage"),
		(.shouldShowDateItem, "preferences.status.clock")
	]

	private func addStatusSection(to column: NSStackView, at index: Int) {
		let title = NSTextField(labelWithString: "preferences.status.title".localized)
		let checkboxes: [NSView] = PreferencesViewController.statusOptions.map { key, label in
			let checkbox = NSButton(checkboxWithTitle: label.localized, target: self, action: #selector(didChangeStatusOption(_:)))
			checkbox.identifier = NSUserInterfaceItemIdentifier(key.rawValue)
			checkbox.state = Preferences[key] == true ? .on : .off
			return checkbox
		}
		let half = (checkboxes.count + 1) / 2
		let grid = NSStackView(views: [NSStackView(views: Array(checkboxes.prefix(half))), NSStackView(views: Array(checkboxes.dropFirst(half)))])
		grid.orientation = .horizontal
		grid.alignment = .top
		grid.spacing = 24
		grid.arrangedSubviews.compactMap { $0 as? NSStackView }.forEach {
			$0.orientation = .vertical
			$0.alignment = .leading
			$0.spacing = 4
		}
		statusFormatField.stringValue = Preferences[.timeFormatTextField]
		statusFormatField.placeholderString = "EE dd MMM HH:mm"
		statusFormatField.target = self
		statusFormatField.action = #selector(didChangeStatusFormat(_:))
		statusFormatField.widthAnchor.constraint(equalToConstant: 180).isActive = true
		let formatRow = NSStackView(views: [NSTextField(labelWithString: "preferences.status.clock-format".localized), statusFormatField])
		formatRow.spacing = 8
		let section = NSStackView(views: [title, grid, formatRow])
		section.orientation = .vertical
		section.alignment = .leading
		section.spacing = 6
		section.setCustomSpacing(10, after: grid)
		let separator = NSBox()
		separator.boxType = .separator
		column.insertArrangedSubview(separator, at: index)
		column.insertArrangedSubview(section, at: index + 1)
		separator.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
		addDockSection(to: column, at: index + 2)
	}

	// MARK: Dock

	private static let dockOptions: [(Preferences.Keys, String)] = [
		(.hideFinder, "preferences.dock.hide-finder"),
		(.showOnlyRunningApps, "preferences.dock.only-running"),
		(.hideRunningIndicator, "preferences.dock.hide-indicator"),
		(.hideBadges, "preferences.dock.hide-badges"),
		(.hidePersistentItems, "preferences.dock.hide-folders"),
		(.hideTrash, "preferences.dock.hide-trash")
	]

	private func addDockSection(to column: NSStackView, at index: Int) {
		let title = NSTextField(labelWithString: "preferences.dock.title".localized)
		let description = NSTextField(wrappingLabelWithString: "preferences.dock.desc".localized)
		description.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
		description.textColor = .secondaryLabelColor
		description.preferredMaxLayoutWidth = 440
		let checkboxes: [NSView] = PreferencesViewController.dockOptions.map { key, label in
			let checkbox = NSButton(checkboxWithTitle: label.localized, target: self, action: #selector(didChangeDockOption(_:)))
			checkbox.identifier = NSUserInterfaceItemIdentifier(key.rawValue)
			checkbox.state = Preferences[key] == true ? .on : .off
			return checkbox
		}
		let half = (checkboxes.count + 1) / 2
		let grid = NSStackView(views: [NSStackView(views: Array(checkboxes.prefix(half))), NSStackView(views: Array(checkboxes.dropFirst(half)))])
		grid.orientation = .horizontal
		grid.alignment = .top
		grid.spacing = 24
		grid.arrangedSubviews.compactMap { $0 as? NSStackView }.forEach {
			$0.orientation = .vertical
			$0.alignment = .leading
			$0.spacing = 4
		}
		let section = NSStackView(views: [title, description, grid])
		section.orientation = .vertical
		section.alignment = .leading
		section.spacing = 6
		section.setCustomSpacing(10, after: description)
		let separator = NSBox()
		separator.boxType = .separator
		column.insertArrangedSubview(separator, at: index)
		column.insertArrangedSubview(section, at: index + 1)
		separator.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
		addWeatherSection(to: column, at: index + 2)
	}

	// MARK: Weather

	private let weatherCityField = NSTextField()
	private let weatherResultsPopUp = NSPopUpButton()
	private let weatherStatusLabel = NSTextField(labelWithString: "")
	private var weatherResults: [WeatherPlace] = []

	private func addWeatherSection(to column: NSStackView, at index: Int) {
		let title = NSTextField(labelWithString: "preferences.weather.title".localized)
		weatherCityField.placeholderString = "preferences.weather.city-placeholder".localized
		weatherCityField.stringValue = Preferences[.weatherCity]
		weatherCityField.target = self
		weatherCityField.action = #selector(searchWeatherCity(_:))
		weatherCityField.widthAnchor.constraint(equalToConstant: 200).isActive = true
		weatherResultsPopUp.target = self
		weatherResultsPopUp.action = #selector(didPickWeatherPlace(_:))
		weatherResultsPopUp.isHidden = true
		let cityRow = NSStackView(views: [NSTextField(labelWithString: "preferences.weather.city".localized), weatherCityField, weatherResultsPopUp])
		cityRow.spacing = 8
		weatherStatusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
		weatherStatusLabel.textColor = .secondaryLabelColor
		let current: String = Preferences[.weatherCity]
		weatherStatusLabel.stringValue = current.isEmpty ? "preferences.weather.automatic".localized : (WeatherStore.place?.displayName ?? current)
		let units = NSSegmentedControl(labels: ["°C", "°F"], trackingMode: .selectOne, target: self, action: #selector(didChangeWeatherUnits(_:)))
		units.selectedSegment = WeatherStore.usesFahrenheit ? 1 : 0
		let description = NSButton(checkboxWithTitle: "preferences.weather.description".localized, target: self, action: #selector(didChangeWeatherDescription(_:)))
		description.state = Preferences[.weatherShowDescription] == true ? .on : .off
		let optionsRow = NSStackView(views: [units, description])
		optionsRow.spacing = 12
		let section = NSStackView(views: [title, cityRow, weatherStatusLabel, optionsRow])
		section.orientation = .vertical
		section.alignment = .leading
		section.spacing = 6
		let separator = NSBox()
		separator.boxType = .separator
		column.insertArrangedSubview(separator, at: index)
		column.insertArrangedSubview(section, at: index + 1)
		separator.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
	}

	@objc private func searchWeatherCity(_ field: NSTextField) {
		let query = field.stringValue.trimmingCharacters(in: .whitespaces)
		guard !query.isEmpty else {
			return
		}
		weatherStatusLabel.stringValue = "preferences.weather.searching".localized
		WeatherStore.search(query) { [weak self] places in
			guard let self = self else {
				return
			}
			self.weatherResults = places
			self.weatherResultsPopUp.removeAllItems()
			self.weatherResultsPopUp.addItems(withTitles: places.map(\.displayName))
			self.weatherResultsPopUp.isHidden = places.count < 2
			if places.isEmpty {
				self.weatherStatusLabel.stringValue = "preferences.weather.not-found".localized
			} else {
				self.applyWeatherPlace(places[0])
			}
		}
	}

	@objc private func didPickWeatherPlace(_ popUp: NSPopUpButton) {
		guard weatherResults.indices.contains(popUp.indexOfSelectedItem) else {
			return
		}
		applyWeatherPlace(weatherResults[popUp.indexOfSelectedItem])
	}

	private func applyWeatherPlace(_ place: WeatherPlace) {
		WeatherStore.place = place
		weatherCityField.stringValue = place.name
		weatherStatusLabel.stringValue = place.displayName
		NotificationCenter.default.post(name: .weatherDidChange, object: nil)
	}

	@objc private func didChangeWeatherUnits(_ control: NSSegmentedControl) {
		Preferences[.weatherUnits] = control.selectedSegment == 1 ? "fahrenheit" : "celsius"
		NotificationCenter.default.post(name: .weatherDidChange, object: nil)
	}

	@objc private func didChangeWeatherDescription(_ checkbox: NSButton) {
		Preferences[.weatherShowDescription] = checkbox.state == .on
		NotificationCenter.default.post(name: .weatherDidChange, object: nil)
	}

	@objc private func didChangeDockOption(_ checkbox: NSButton) {
		guard let raw = checkbox.identifier?.rawValue, let key = Preferences.Keys(rawValue: raw) else {
			return
		}
		Preferences[key] = checkbox.state == .on
		NotificationCenter.default.post(name: .dockDidChange, object: nil)
	}

	@objc private func didChangeStatusOption(_ checkbox: NSButton) {
		guard let raw = checkbox.identifier?.rawValue, let key = Preferences.Keys(rawValue: raw) else {
			return
		}
		Preferences[key] = checkbox.state == .on
		NotificationCenter.default.post(name: .statusDidChange, object: nil)
	}

	@objc private func didChangeStatusFormat(_ field: NSTextField) {
		let format = field.stringValue.trimmingCharacters(in: .whitespaces)
		Preferences[.timeFormatTextField] = format.isEmpty ? "EE dd MMM HH:mm" : format
		NotificationCenter.default.post(name: .statusDidChange, object: nil)
	}

	@objc private func didChangeControlsButton(_ checkbox: NSButton) {
		guard let id = checkbox.identifier?.rawValue else {
			return
		}
		var enabled = ControlsButton.enabled.map(\.rawValue)
		if checkbox.state == .on {
			enabled.append(id)
		} else {
			enabled.removeAll { $0 == id }
		}
		Preferences[.controlsButtons] = enabled
		NotificationCenter.default.post(name: .controlsDidChange, object: nil)
	}

	@objc private func didChangeFocusShortcut(_ field: NSTextField) {
		let name = field.stringValue.trimmingCharacters(in: .whitespaces)
		Preferences[.focusShortcutName] = name.isEmpty ? "Toggle Focus" : name
	}

	private func reloadNativeAppsList() {
		nativeAppsList.arrangedSubviews.forEach { $0.removeFromSuperview() }
		let apps: [String] = Preferences[.nativeTouchBarApps]
		for bundleIdentifier in apps {
			let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
			let name = url.map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") } ?? bundleIdentifier
			let checkbox = NSButton(checkboxWithTitle: name, target: self, action: #selector(removeNativeTouchBarApp(_:)))
			checkbox.state = .on
			checkbox.identifier = NSUserInterfaceItemIdentifier(bundleIdentifier)
			checkbox.toolTip = "preferences.native-apps.remove".localized
			if let url = url {
				let icon = NSWorkspace.shared.icon(forFile: url.path)
				icon.size = NSSize(width: 16, height: 16)
				checkbox.image = icon
				checkbox.imagePosition = .imageLeft
			}
			nativeAppsList.addArrangedSubview(checkbox)
		}
	}

	private func setNativeTouchBarApps(_ apps: [String]) {
		Preferences[.nativeTouchBarApps] = apps
		reloadNativeAppsList()
	}

	@objc private func removeNativeTouchBarApp(_ checkbox: NSButton) {
		guard let id = checkbox.identifier?.rawValue else {
			return
		}
		let apps: [String] = Preferences[.nativeTouchBarApps]
		setNativeTouchBarApps(apps.filter { $0 != id })
	}

	@objc private func addNativeTouchBarApp() {
		let panel = NSOpenPanel()
		panel.directoryURL = URL(fileURLWithPath: "/Applications")
		panel.allowedFileTypes = ["app"]
		panel.allowsMultipleSelection = true
		guard let window = view.window else {
			return
		}
		panel.beginSheetModal(for: window) { [weak self] response in
			guard response == .OK else {
				return
			}
			var apps: [String] = Preferences[.nativeTouchBarApps]
			for id in panel.urls.compactMap({ Bundle(url: $0)?.bundleIdentifier }) where !apps.contains(id) {
				apps.append(id)
			}
			self?.setNativeTouchBarApps(apps)
		}
	}

	@objc private func didChangeAppProfile(_ checkbox: NSButton) {
		guard let id = checkbox.identifier?.rawValue else {
			return
		}
		var disabled = AppControlsTouchBarItem.disabledProfiles
		if checkbox.state == .on {
			disabled.remove(id)
		} else {
			disabled.insert(id)
		}
		AppControlsTouchBarItem.disabledProfiles = disabled
	}

	/// Creates the custom profiles file with an example on first use, then reveals it.
	@objc private func openCustomAppProfiles() {
		let url = AppControlsTouchBarItem.customProfilesURL
		if !FileManager.default.fileExists(atPath: url.path) {
			let example = [AppProfile(id: "example", name: "Example (TextEdit)", apps: ["com.apple.TextEdit"], actions: [
				AppAction(title: "Bold", symbol: "bold", shortcut: "cmd+b"),
				AppAction(title: "Italic", symbol: "italic", shortcut: "cmd+i")
			])]
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
			try? encoder.encode(example).write(to: url)
		}
		NSWorkspace.shared.activateFileViewerSelecting([url])
	}

	@objc private func didChangeModifierTouchBarOption(_ checkbox: NSButton) {
		guard ModifierTouchBarMode.allCases.indices.contains(checkbox.tag) else {
			return
		}
		let mode = ModifierTouchBarMode.allCases[checkbox.tag]
		Preferences[mode.preferenceKey] = checkbox.state == .on
		if mode == .windowLayout, checkbox.state == .on, !WindowManager.isTrusted {
			WindowManager.requestAccess()
		}
	}

	// MARK: Core-update stuff
	
	private func shouldAskToupdate(_ completion: @escaping (Version?) -> Void) {
		AppController.shared.fetchLatestVersions { [completion] in
			let currentVersion = Updater.fullAppVersion
            if let core = Updater.cachedLatestReleases?.core, core.name.isGreatherThan(currentVersion) {
				completion(core)
			} else {
				completion(nil)
			}
		}
	}
	
	@IBAction private func checkForUpdates(_ sender: NSButton) {
        checkForUpdatesSpinner.startAnimation(nil)
		checkForUpdatesNowButton.isEnabled = false
		checkForUpdatesNowButton.title = "general.action.checking".localized
        async(after: 1) { [weak self] in
            self?.shouldAskToupdate { [weak self] newVersion in
                guard let self = self else {
                    return
                }
                let newVersionAvailable = newVersion != nil
                self.checkForUpdatesNowButton.title = newVersionAvailable ? "preferences.updates.new-version-available.title".localized : "general.action.check-for-updates".localized
                self.checkForUpdatesNowButton.bezelColor = newVersionAvailable ? .controlAccentColor : .windowFrameColor
                self.checkForUpdatesNowButton.isEnabled = true
                self.checkForUpdatesSpinner.stopAnimation(nil)
                self.showUpdateAlert(for: newVersion)
            }
        }
	}
	
	private func showUpdateAlert(for version: Version?) {
		let currentVersion = Updater.fullAppVersion
		if let newVersion = version {
			self.showAlert(
				title: "preferences.updates.new-version-available.title".localized,
				message: "preferences.updates.new-version-available.message".localized(currentVersion, newVersion.name),
				buttons: ["general.action.update".localized, "general.action.later".localized],
				completion: { response in
					switch response {
					case .alertFirstButtonReturn:
						async {
							AppController.shared.openWebsite(newVersion.link)
						}
					default:
						return
					}
				}
			)
		} else {
			self.showAlert(
				title: "preferences.updates.already-on-latest-version.title".localized(currentVersion),
				message: "preferences.updates.already-on-latest-version.message".localized
			)
		}
	}
	
	private func showAlert(title: String, message: String, buttons: [String] = [], completion: ((NSApplication.ModalResponse) -> Void)? = nil) {
		async { [weak self] in
			guard let window = self?.view.window else {
				return
			}
			let alert = NSAlert()
			alert.alertStyle = NSAlert.Style.informational
			alert.messageText = title
			alert.informativeText = message
			for buttonTitle in buttons {
				alert.addButton(withTitle: buttonTitle)
			}
			alert.beginSheetModal(for: window, completionHandler: completion)
		}
	}
	
}
