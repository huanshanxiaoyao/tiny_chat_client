//
//  DialogModels.swift
//  AIChatClient2
//
//  Created by 苏冲 on 2024/10/16.
//

// DialogModels.swift

import SwiftUI

// MARK: - Confirmation Model

class ConfirmationModel: ObservableObject {
    @Published var showConfirmationDialog = false
    @Published var confirmationMessage = ""
    @Published var currentTitle = ""
    @Published var currentSSID = ""
}

// MARK: - Alert Model

class AlertModel: ObservableObject {
    @Published var showAlert = false
    @Published var alertMessage = ""
}

class CourseModel:ObservableObject {
    @Published var course_id = false
    @Published var course_title = ""
}

