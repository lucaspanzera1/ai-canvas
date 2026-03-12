// ModelInfo.swift
import Foundation
import SwiftUI

struct ModelInfo: Identifiable, Equatable {
    let id: String            // usually the model id, e.g. "gpt-4o"
    let displayName: String   // friendly name shown in UI, e.g. "GPT-4o"
    let provider: AIProvider

    // Simple comparison attributes (normalized 1...5)
    let speed: Int            // higher is faster
    let quality: Int          // higher is better quality
    let cost: Int             // higher is more expensive

    // Capabilities
    let visionCapable: Bool

    // Optional notes or tags to show in UI
    let notes: String?
}
