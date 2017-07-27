//
//  StatusMenuController.swift
//  TeamStatus
//
//  Created by Marcin Religa on 31/05/2017.
//  Copyright © 2017 Marcin Religa. All rights reserved.
//

import Cocoa

class StatusMenuController: NSObject {
	@IBOutlet var statusMenu: NSMenu!
	@IBOutlet var reviewerView: ReviewerView!
	@IBOutlet var tableView: NSTableView!

	private var viewModel: MainViewModel!

	let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)

	// TODO: How to do it properly?
	var viewDidLoad = false

	override func awakeFromNib() {
		if viewDidLoad == false {
			let token = CommandLine.arguments[1]
			viewModel = MainViewModel(view: self, token: token)
			viewModel.run()

			let icon = NSImage(named: "statusIcon")
			icon?.isTemplate = true // best for dark mode
			statusItem.image = icon
			statusItem.menu = statusMenu

			if let reviewerMenuItem = self.statusMenu.item(withTitle: "Reviewer") {
				reviewerMenuItem.view = reviewerView
			}

			let timer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(self.refresh), userInfo: nil, repeats: true)
			RunLoop.main.add(timer, forMode: .commonModes)

			viewDidLoad = true
		}
	}

	func refresh() {
		print("auto refresh")
		viewModel.run()
	}

	@IBAction func quitClicked(sender: NSMenuItem) {
		NSApplication.shared().terminate(self)
	}

	@IBAction func refreshClicked(sender: NSButton) {
		print("refresh")
		viewModel.run()
	}

	fileprivate var reviewers: [Reviewer]?
	fileprivate var pullRequests: [PullRequest]?
	fileprivate var viewer: Viewer?
}

extension StatusMenuController: MainViewProtocol {
	func didFinishRunning(reviewers: [Reviewer], pullRequests: [PullRequest], viewer: Viewer?) {

		self.reviewers = reviewers
		self.pullRequests = pullRequests
		self.viewer = viewer

		DispatchQueue.main.async {
			self.tableView.reloadData()
		}
	}

	func didFailToRun() {

	}

	func updateStatusItem(title: String) {
		statusItem.title = title
	}
}

extension StatusMenuController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		return reviewers?.count ?? 0
	}
}

extension StatusMenuController: NSTableViewDelegate {
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let tableColumn = tableColumn else {
			fatalError()
		}

		switch tableColumn.identifier {
		case "UserLoginTableColumn":
			guard let cell = tableView.make(withIdentifier: "ReviewerCellView", owner: self) as? ReviewerCellView else {
				fatalError()
			}

			guard let reviewers = reviewers else {
				return nil
			}

			let reviewer = reviewers[row]

			cell.loginLabel.stringValue = reviewer.login
			return cell
		case "RequestedInTableColumn":
			guard let cell = tableView.make(withIdentifier: "RequestedInCellView", owner: self) as? RequestedInCellView else {
				fatalError()
			}

			guard let reviewers = reviewers, let pullRequests = pullRequests else {
				return nil
			}

			let reviewer = reviewers[row]

			let prsToReview = reviewer.PRsToReview(in: pullRequests).count
			let prsReviewed = reviewer.PRsReviewed(in: pullRequests).count
			let totalPRs = prsToReview + prsReviewed
			cell.pullRequestsToReviewLabel.stringValue = ""
			cell.levelIndicator.integerValue = prsReviewed
			cell.levelIndicator.maxValue = Double(totalPRs)
			cell.levelIndicator.warningValue = 0.5 * Double(totalPRs)
			cell.levelIndicator.criticalValue = 0.25 * Double(totalPRs)
			return cell
		case "ReviewedTableColumn":
			guard let cell = tableView.make(withIdentifier: "ReviewedCellView", owner: self) as? ReviewedCellView else {
				fatalError()
			}

			guard let reviewers = reviewers, let pullRequests = pullRequests else {
				return nil
			}

			let reviewer = reviewers[row]

			let prsToReview = reviewer.PRsToReview(in: pullRequests).count
			let prsReviewed = reviewer.PRsReviewed(in: pullRequests).count
			let totalPRs = prsToReview + prsReviewed

			cell.pullRequestsReviewedLabel.stringValue = "\(prsReviewed) of \(totalPRs)"
			return cell
		case "AvatarTableColumn":
			guard let cell = tableView.make(withIdentifier: "AvatarCellView", owner: self) as? AvatarCellView else {
				fatalError()
			}

			guard let reviewers = reviewers else {
				return nil
			}

			let reviewer = reviewers[row]

			if let imageURL = reviewer.avatarURL {
				//let image = NSImage(byReferencing: imageURL)
				cell.imageView?.imageFromServerURL(urlString: imageURL.absoluteString)
			}

			return cell
		default:
			fatalError()
		}

	}
}

extension NSImageView {
	public func imageFromServerURL(urlString: String) {

		URLSession.shared.dataTask(with: NSURL(string: urlString)! as URL, completionHandler: { (data, response, error) -> Void in

			if error != nil {
				//print(error)
				return
			}
			DispatchQueue.main.async(execute: { () -> Void in
				let image = NSImage(data: data!)
				self.image = image
			})

		}).resume()
	}
}

