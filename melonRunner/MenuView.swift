//
//  MainScreen.swift
//  melonRunner
//
//  Created by Emelyanov Artem on 29.07.2025.
//

import UIKit
import SwiftUI

class MenuView: UIViewController {

    private let button: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Open Running View", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let debugLabel: UILabel = {
        let label = UILabel()
        label.text = "Debug Label"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 24)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        print("MenuView loaded")

        view.backgroundColor = .white
        view.addSubview(button)
        view.addSubview(debugLabel)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            debugLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            debugLabel.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 20)
        ])

        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    @objc private func buttonTapped() {
        let runningView = UIHostingController(rootView: RunningView())
        present(runningView, animated: true, completion: nil)
    }
}
