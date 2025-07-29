//
//  MenuRepresenter.swift
//  melonRunner
//
//  Created by Emelyanov Artem on 29.07.2025.
//

import SwiftUI
import UIKit

struct MenuViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MenuView {
        return MenuView()
    }

    func updateUIViewController(_ uiViewController: MenuView, context: Context) {
        // Обновление состояния контроллера, если необходимо
    }
}
