//
//  ViewController.swift
//  AVFoundationDemo
//
//  Created by Gennadiy Mishin on 15.09.2020.
//  Copyright © 2020 GM. All rights reserved.
//

import UIKit
import AVKit

class VideoCompositionController: UIViewController {

    private lazy var exportButton: UIBarButtonItem = {
        let item = UIBarButtonItem(barButtonSystemItem: .action,
                                   target: self,
                                   action: #selector(exportButtonAction(_:)))
        return item
    }()
    private lazy var addVideoButton: UIBarButtonItem = {
        let item = UIBarButtonItem(barButtonSystemItem: .add,
                                   target: self,
                                   action: #selector(addButtonAction(_:)))
        return item
    }()
    private lazy var pipVideoButton: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "Make PiP",
                                   style: .done,
                                   target: self,
                                   action: #selector(pipButtonAction(_:)))
        return item
    }()
    private lazy var clearButton: UIBarButtonItem = {
        let item = UIBarButtonItem(barButtonSystemItem: .trash,
                                   target: self,
                                   action: #selector(clearButtonAction(_:)))
        return item
    }()
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.dataSource = self
        tableView.register(MediaItemCell.self, forCellReuseIdentifier: String(describing: MediaItemCell.self))
        tableView.setEditing(true, animated: false)
        tableView.tableFooterView = UIView()
        return tableView
    }()
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .whiteLarge)
        view.color = UIColor.gray
        return view
    }()
    
    let viewModel = VideoCompositionViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
        updateUI()
    }
    
    // MARK: - UI
    
    private func setupUI() {
        view.backgroundColor = .green
        navigationItem.title = "Video Composition"
        
        exportButton.isEnabled = false
        navigationItem.rightBarButtonItem = exportButton
        navigationItem.leftBarButtonItem = pipVideoButton
        
        view.addSubview(tableView)
        
        activityIndicator.isHidden = true
        view.addSubview(activityIndicator)
        
        let flexButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let toolbarItems = [clearButton, flexButton, addVideoButton]
        setToolbarItems(toolbarItems, animated: false)
    }
    
    private func updateUI(reloadTable: Bool = true) {
        exportButton.isEnabled = viewModel.mediaURLs.count > 1
        pipVideoButton.isEnabled = viewModel.mediaURLs.count == 2
        if reloadTable {
            tableView.reloadData()
        }
        clearButton.isEnabled = !viewModel.mediaURLs.isEmpty
    }
    
    // MARK: - Layout
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        let safeArea = view.safeAreaInsets
        
        tableView.frame = view.bounds
        tableView.contentInset = UIEdgeInsets(top: safeArea.top, left: safeArea.left, bottom: safeArea.bottom, right: safeArea.right)
        tableView.scrollIndicatorInsets = tableView.contentInset
        
        activityIndicator.center = view.center
    }
    
    // MARK: - Actions
    
    @objc private func clearButtonAction(_ sender: UIButton) {
        viewModel.mediaURLs.removeAll()
        updateUI()
    }
    
    @objc private func addButtonAction(_ sender: UIButton) {
        let ac = UIAlertController(title: "Select media source", message: nil, preferredStyle: .actionSheet)
        ac.popoverPresentationController?.barButtonItem = addVideoButton
        
        for source in MediaPickerController.availableSources() {
            var title = ""
            switch source {
            case .camera:
                title = "Camera"
            case .photoLibrary:
                title = "Photo Library"
            case .savedPhotosAlbum:
                title = "Saved Photos Album"
            default:
                break
            }
            if !title.isEmpty {
                ac.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] (_) in
                    self?.presentMediaPicker(source: source)
                }))
            }
        }
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(ac, animated: true, completion: nil)
    }
    
    @objc private func pipButtonAction(_ sender: UIBarButtonItem) {
        checkAccessToPhotos { [weak self] in
            guard let self = self else { return }
            self.activityIndicator.startAnimating()
            self.viewModel.exportPiPVideo { [weak self] (result) in
                guard let self = self else { return }
                self.handleExportResult(result)
            }
        }
    }
    
    @objc private func exportButtonAction(_ sender: UIBarButtonItem) {
        checkAccessToPhotos { [weak self] in
            guard let self = self else { return }
            self.activityIndicator.startAnimating()
            self.viewModel.exportVideo { [weak self] (result) in
                guard let self = self else { return }
                self.handleExportResult(result)
            }
        }
    }
    
    private func checkAccessToPhotos(completion: (() -> Void)?) {
        viewModel.requestAccessToPhotosIfNeeded { [weak self] (granted) in
            guard let self = self else { return }
            guard granted else {
                let ac = UIAlertController(title: "Photo library access denied",
                                           message: "Allow access in Settings",
                                           preferredStyle: .alert)
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }

                let settingsAction = UIAlertAction(title: "Settings", style: .default, handler: { _ in
                    if UIApplication.shared.canOpenURL(settingsUrl) {
                        UIApplication.shared.open(settingsUrl, completionHandler: nil)
                    }
                })
                ac.addAction(settingsAction)
                ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                self.present(ac, animated: true, completion: nil)
                return
            }
            
            completion?()
        }
    }
    
    private func handleExportResult(_ result: Swift.Result<URL, Error>) {
        switch result {
        case .failure(let error):
            activityIndicator.stopAnimating()
            presentErrorAlert(title: "Export failed", error: error)
        case .success(let url):
            viewModel.saveMediaToCameraRoll(url: url) { [weak self] (error) in
                guard let self = self else { return }
                self.activityIndicator.stopAnimating()
                if let error = error {
                    self.presentErrorAlert(title: "Failed save to Photos", error: error)
                    return
                }
                self.presentAssetPreview(url: url)
            }
        }
    }
    
    // MARK: - Navigation
    
    private func presentErrorAlert(title: String, error: Error?) {
        let ac = UIAlertController(title: title,
                                   message: error?.localizedDescription,
                                   preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: "Close", style: .default, handler: nil)
        ac.addAction(defaultAction)
        self.present(ac, animated: true, completion: nil)
    }
    
    private func presentMediaPicker(source: MediaPickerController.SourceType) {
        let vc = MediaPickerController()
        vc.prepareVideoPicker(source: source)
        vc.completion = { [weak self] url in
            guard let self = self else { return }
            self.dismiss(animated: true, completion: nil)
            self.viewModel.mediaURLs.append(url)
            self.updateUI()
        }
        vc.dismissCompletion = { [weak self] in
            guard let self = self else { return }
            self.dismiss(animated: true, completion: nil)
        }
        present(vc, animated: true, completion: nil)
    }
    
    private func presentAssetPreview(url: URL) {
        let player = AVPlayer(url: url)
        let vcPlayer = AVPlayerViewController()
        vcPlayer.player = player
        self.present(vcPlayer, animated: true, completion: nil)
    }
}

extension VideoCompositionController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.mediaURLs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // skip reusable for now
        let cell = MediaItemCell(style: .subtitle, reuseIdentifier: nil)
        let url = viewModel.mediaURLs[indexPath.row]
        cell.updateUI(assetURL: url)
        return cell
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let item = viewModel.mediaURLs.remove(at: sourceIndexPath.row)
        viewModel.mediaURLs.insert(item, at: destinationIndexPath.row)
        updateUI(reloadTable: false)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete:
            viewModel.mediaURLs.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            updateUI(reloadTable: false)
        default:
            break
        }
    }
}

extension VideoCompositionController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = viewModel.mediaURLs[indexPath.row]
        presentAssetPreview(url: item)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}
