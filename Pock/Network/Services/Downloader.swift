//
//  Downloader.swift
//  Pock
//
//  Created by Pierluigi Galdi on 05/05/21.
//

import Foundation

// MARK: Error
internal enum DownloaderError: PockError {
	case invalidFileURL
	case responseError(reason: String?)
	case downloadError(reason: String?)
	case fileSystemError(reason: String?)
	var description: String {
		switch self {
		case .invalidFileURL:
			return "error.downloader.invalid-file-url".localized
		case .responseError(let reason):
			return "error.downloader.response-error".localized(reason ?? "")
		case .downloadError(let reason):
			return "error.downloader.download-error".localized(reason ?? "")
		case .fileSystemError(let reason):
			return "error.file-system-error".localized(reason ?? "")
		}
	}
}

internal class Downloader: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate {
	
	private let progress: (Double) -> Void
	private let completion: (URL?, DownloaderError?) -> Void
	
	private var session: URLSession!
    private var didComplete = false

    // URLSession serializes delegate calls. Deliver one result and break its
    // strong reference to this delegate on success and failure alike.
    private func finish(_ location: URL?, _ error: DownloaderError?) {
        guard !didComplete else { return }
        didComplete = true
        completion(location, error)
        session.finishTasksAndInvalidate()
        downloadTask = nil
        session = nil
    }
	private var downloadTask: URLSessionDownloadTask!
	
	@discardableResult
	init(url: URL, progress: @escaping (Double) -> Void, completion: @escaping (URL?, DownloaderError?) -> Void) {
		self.progress = progress
		self.completion = completion
		super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
		self.downloadTask = session.downloadTask(with: url)
		self.downloadTask.resume()
	}
	
	// MARK: Handle progress
	
	func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didWriteData bytesWritten: Int64,
		totalBytesWritten: Int64,
		totalBytesExpectedToWrite: Int64
	) {
		if downloadTask == self.downloadTask, totalBytesExpectedToWrite > 0 {
			let calculatedProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
			progress(min(1, max(0, calculatedProgress)))
		}
	}
	
	// MARK: Handle completion
	
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		guard let response = downloadTask.response as? HTTPURLResponse else {
			finish(nil, .responseError(reason: nil))
			return
		}
		switch response.statusCode {
		case 200...299:
			break
		case 404:
			finish(nil, .invalidFileURL)
			return
		default:
			finish(nil, .responseError(reason: response.statusCode.description))
			return
		}
		guard FileManager.default.createFolderIfNeeded(at: kWidgetsTempPathURL.path) else {
			finish(nil, .fileSystemError(reason: "error.missing-widgets-temp-folder".localized))
			return
		}
		do {
			let destinationURL = kWidgetsTempPathURL.appendingPathComponent(location.lastPathComponent)
			try FileManager.default.moveItem(at: location, to: destinationURL)
			finish(destinationURL, nil)
		} catch {
			finish(nil, .downloadError(reason: error.localizedDescription))
		}
	}
	
	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		if let error = error {
			finish(nil, .downloadError(reason: error.localizedDescription))
		}
	}
	
}

// MARK: Default widgets downloader

internal class DefaultWidgetsDownloader {
	
    // Debug builds use the same maintained catalog as release builds.
    private let defaultWidgetsURLString = "https://pock.app/api/defaults.php"
	
	// MARK: Fetch default widgets list
	
	internal func fetchDefaultWidgets(_ completion: @escaping ([String: URL], DownloaderError?) -> Void) {
		guard let url = URL(string: defaultWidgetsURLString + "?core=\(Updater.fullAppVersion)") else {
			completion([:], .invalidFileURL)
			return
		}
		let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
		let task = URLSession.shared.dataTask(with: request) { data, response, error in
			if let error = error {
				Roger.error(error)
				completion([:], .responseError(reason: error.localizedDescription))
				return
			}
			guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
				completion([:], .responseError(reason: "Invalid response code"))
				return
			}
			guard httpResponse.mimeType == "application/json", let data = data else {
				completion([:], .responseError(reason: "Invalid response data"))
				return
			}
			do {
				let list = try JSONDecoder().decode([String: URL].self, from: data)
				completion(list, nil)
			} catch {
				Roger.error(error)
				completion([:], .responseError(reason: "Invalid response data"))
			}
		}
		task.resume()
	}
	
}
