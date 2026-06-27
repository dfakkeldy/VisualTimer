import Foundation

struct WatchTemplate: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let firstDurationSeconds: Int
}

enum WatchTemplateLibrary {
    static let templates = [
        WatchTemplate(id: "quick", title: "Quick Timer", subtitle: "Set with the crown", firstDurationSeconds: 25),
        WatchTemplate(id: "game-night", title: "Game Night", subtitle: "One-minute turns", firstDurationSeconds: 60),
        WatchTemplate(id: "recipe-steps", title: "Recipe Steps", subtitle: "Start with prep", firstDurationSeconds: 60),
        WatchTemplate(id: "plant-watering", title: "Plant Watering", subtitle: "Start with herbs", firstDurationSeconds: 45),
    ]
}
