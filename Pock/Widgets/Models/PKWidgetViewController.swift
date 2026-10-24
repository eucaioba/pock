//
//  PKWidgetViewController.swift
//  Pock
//
//  Created by Pierluigi Galdi on 11/03/21.
//

import AppKit
import PockKit

internal class PKWidgetViewController: NSViewController {
	
	/// Data
	private weak var widgetItem: PKWidgetTouchBarItem!
	private var widgetIdentifier: String!
	
	/// Initialiser
	convenience init(item: PKWidgetTouchBarItem) {
		self.init()
		widgetIdentifier = item.identifier.rawValue
		widgetItem = item
		view = item.widget!.view
	}
	
	deinit {
		Roger.debug("[\(widgetIdentifier ?? "Unknown")][viewController] - deinit")
	}
	
	/// Overrides
	///
	/// The Touch Bar shows and hides items from inside its own layout pass, e.g. when items no longer fit.
	/// Widgets rebuild their views in these callbacks, and changing constraints during layout throws,
	/// so callbacks are forwarded on the next run loop iteration, in order.
	/// The widget is captured now so a disappearing item still receives its cleanup callbacks.
	private func forward(_ callback: @escaping (PKWidget) -> Void) {
		guard let widget = widgetItem?.widget else {
			return
		}
		DispatchQueue.main.async {
			callback(widget)
		}
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		forward { $0.viewWillAppear?() }
	}

	override func viewDidAppear() {
		super.viewDidAppear()
		forward { $0.viewDidAppear?() }
	}

	override func viewWillDisappear() {
		super.viewWillDisappear()
		forward { $0.viewWillDisappear?() }
	}

	override func viewDidDisappear() {
		super.viewDidDisappear()
		forward { $0.viewDidDisappear?() }
	}

}
