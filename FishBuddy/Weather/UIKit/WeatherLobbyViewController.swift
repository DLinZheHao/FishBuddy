//
//  WeatherLobbyViewController.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/15.
//

import UIKit
import Combine
import SwiftUI

class WeatherLobbyViewController: UIViewController {

    // viewModel
    var vm = WeatherLobbyVM()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addSwiftUIView()
        observeLocationDetail()
        vm.loadWeatherOnLaunch()
    }

    /// 觀察 vm.locationDetail，有值時 push LocationDetailView
    private func observeLocationDetail() {
        vm.$locationDetail
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detail in
                guard let self else { return }
                let detailView = LocationDetailView(response: detail)
                let hostingVC = UIHostingController(rootView: detailView)
                self.navigationController?.pushViewController(hostingVC, animated: true)
                // reset 防止重複 push
                self.vm.locationDetail = nil
            }
            .store(in: &vm.cancellables)
    }

    private func addSwiftUIView() {
        let swiftUIView = CityWeatherView(vm: vm)
        let hostingController = UIHostingController(rootView: swiftUIView)

        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
}
