//
//  ModelContextExtensions.swift
//  Momentum
//
//  Extension for safer ModelContext operations with error handling
//

import SwiftData
import SwiftUI
import OSLog
import MomentumKit

extension ModelContext {
    /// Safely saves the model context with error handling and logging
    /// - Parameter onError: Optional closure called when save fails, receives error message
    /// - Returns: Boolean indicating success
    @discardableResult
    func safeSave(onError: ((String) -> Void)? = nil) -> Bool {
        do {
            try save()
            return true
        } catch {
            let errorMessage = "Failed to save data: \(error.localizedDescription)"
            AppLogger.data.error("\(errorMessage)")
            onError?(errorMessage)
            return false
        }
    }
    
    /// Safely saves with toast notification on error
    /// - Parameter toastConfig: Binding to toast configuration for showing errors
    /// - Returns: Boolean indicating success
    @discardableResult
    func safeSave(showingToast toastConfig: Binding<ToastConfig?>) -> Bool {
        do {
            try save()
            return true
        } catch {
            let errorMessage = "Failed to save changes"
            AppLogger.data.error("Save failed: \(error.localizedDescription)")
            toastConfig.wrappedValue = ToastConfig(message: errorMessage)
            return false
        }
    }
}
