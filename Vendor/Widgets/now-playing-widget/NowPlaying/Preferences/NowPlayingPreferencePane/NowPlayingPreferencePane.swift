//
//  NowPlayingPreferencePane.swift
//  Pock
//
//  Created by Pierluigi Galdi on 14/12/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Cocoa
import PockKit

class NowPlayingPreferencePane: NSViewController, PKWidgetPreference {
    
    static var nibName: NSNib.Name = "NowPlayingPreferencePane"
    
    // MARK: UI Elements
	
	@IBOutlet private weak var defaultApplicationIcon: NSImageView!
	@IBOutlet private weak var defaultApplicationName: NSTextField!
	
    @IBOutlet private weak var imagesStackView:         NSStackView!
    @IBOutlet private weak var defaultRadioButton:      NSButton!
    @IBOutlet private weak var onlyInfoRadioButton:     NSButton!
    @IBOutlet private weak var playPauseRadioButton:    NSButton!
	
    @IBOutlet private weak var hideWidgetIfNoMedia:     NSButton!
    @IBOutlet private weak var animateIconWhilePlaying: NSButton!
	@IBOutlet private weak var showMediaArtwork:		NSButton!
	@IBOutlet private weak var invertSwipeGesture:		NSButton!
    
    func reset() {
        Preferences.reset()
        NotificationCenter.default.post(name: .mrMediaRemoteNowPlayingApplicationDidChange, object: nil)
        NotificationCenter.default.post(name: .mrPlaybackQueueContentItemsChanged, object: nil)
        NotificationCenter.default.post(name: Notification.Name(didChangeNowPlayingWidgetStyle), object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
		switch NowPlayingWidgetStyle(rawValue: Preferences[.nowPlayingWidgetStyle]) ?? .default {
        case .default:
            defaultRadioButton.state = .on
        case .onlyInfo:
            onlyInfoRadioButton.state = .on
        case .playPause:
            playPauseRadioButton.state = .on
        }
		updateDefaultApplicationUIElements()
        updateButtonsState()
        setupImageViewClickGesture()
    }
    
    private func updateDefaultApplicationUIElements() {
        let source = MediaSource(rawValue: Preferences[.preferredMediaSource] as String) ?? .automatic
        defaultApplicationIcon.image = NSWorkspace.shared.applicationIcon(for: source.bundleIdentifier)
        defaultApplicationName.stringValue = source.title
    }

	private func updateButtonsState() {
		hideWidgetIfNoMedia.state     = Preferences[.hideNowPlayingIfNoMedia] ? .on : .off
		animateIconWhilePlaying.state = Preferences[.animateIconWhilePlaying] ? .on : .off
		showMediaArtwork.state 		  = Preferences[.showMediaArtwork] 	   	  ? .on : .off
		invertSwipeGesture.state 	  = Preferences[.invertSwipeGesture] 	  ? .on : .off
	}
	
    private func setupImageViewClickGesture() {
        imagesStackView.arrangedSubviews.forEach({
            $0.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(didSelectRadioButton(_:))))
        })
    }
	
    @IBAction private func didSelectChooseDefaultApplicationButton(_ control: Any?) {
        guard let button = control as? NSView else { return }
        let selected = MediaSource(rawValue: Preferences[.preferredMediaSource] as String) ?? .automatic
        let menu = NSMenu(title: "Fonte de mídia")
        for source in MediaSource.allCases {
            let item = NSMenuItem(title: source.title, action: #selector(didChooseSource(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = source.rawValue
            item.state = source == selected ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY), in: button)
    }

    @objc private func didChooseSource(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let source = MediaSource(rawValue: raw) else { return }
        Preferences[.preferredMediaSource] = source.rawValue
        updateDefaultApplicationUIElements()
        NotificationCenter.default.post(name: Notification.Name(didChangeNowPlayingWidgetStyle), object: nil)
    }

    @IBAction private func didSelectRadioButton(_ control: AnyObject) {
        let view = (control as? NSGestureRecognizer)?.view ?? control
        switch view.tag {
        case 0:
			Preferences[.nowPlayingWidgetStyle] = NowPlayingWidgetStyle.default.rawValue
            defaultRadioButton.state   = .on
            onlyInfoRadioButton.state  = .off
            playPauseRadioButton.state = .off
        case 1:
			Preferences[.nowPlayingWidgetStyle] = NowPlayingWidgetStyle.onlyInfo.rawValue
            defaultRadioButton.state   = .off
            onlyInfoRadioButton.state  = .on
            playPauseRadioButton.state = .off
        case 2:
			Preferences[.nowPlayingWidgetStyle] = NowPlayingWidgetStyle.playPause.rawValue
            defaultRadioButton.state   = .off
            onlyInfoRadioButton.state  = .off
            playPauseRadioButton.state = .on
        default:
            return
        }
		NotificationCenter.default.post(name: .mrPlaybackQueueContentItemsChanged, object: nil)
		NotificationCenter.default.post(name: Notification.Name(didChangeNowPlayingWidgetStyle), object: nil)
    }
    
    @IBAction private func didChangeCheckboxState(_ button: NSButton?) {
        guard let button = button else {
            return
        }
        switch button.tag {
        case 0:
			Preferences[.hideNowPlayingIfNoMedia] = button.state == .on
        case 1:
			Preferences[.animateIconWhilePlaying] = button.state == .on
			if Preferences[.showMediaArtwork] {
				Preferences[.showMediaArtwork] = !Preferences[.animateIconWhilePlaying]
			}
			updateButtonsState()
		case 2:
			Preferences[.showMediaArtwork] = button.state == .on
			if Preferences[.animateIconWhilePlaying] {
				Preferences[.animateIconWhilePlaying] = !Preferences[.showMediaArtwork]
			}
			updateButtonsState()
		case 3:
			Preferences[.invertSwipeGesture] = button.state == .on
        default:
            return
        }
		NotificationCenter.default.post(name: .mrPlaybackQueueContentItemsChanged, object: nil)
        NotificationCenter.default.post(name: Notification.Name(didChangeNowPlayingWidgetStyle), object: nil)
    }
    
}
