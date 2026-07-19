import Foundation

struct StarterTemplate: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let game: GameSequence
}

enum StarterTemplateLibrary {
    static let templates: [StarterTemplate] = [
        gameNight,
        recipeSteps,
        plantWatering,
        classroomStations,
        meetingAgenda,
        morningRoutine,
    ]

    static var defaultTemplate: StarterTemplate { gameNight }

    static func template(id: String) -> StarterTemplate? {
        templates.first { $0.id == id }
    }

    private static let gameNight = StarterTemplate(
        id: "game-night",
        title: "Game Night",
        subtitle: "Player turns plus a table timeout.",
        game: makeGame(
            title: "Game Night",
            rounds: [
                round("Alice", emoji: "🎲", color: 0, seconds: 60),
                round("Bob", emoji: "🎯", color: 1, seconds: 60),
                round("Charlie", emoji: "♟️", color: 2, seconds: 60),
                round("Timeout", emoji: "⏳", color: 4, seconds: 120, countsAsPlayer: false),
            ]
        )
    )

    private static let recipeSteps = StarterTemplate(
        id: "recipe-steps",
        title: "Recipe Steps",
        subtitle: "Prep, simmer, stir, and rest.",
        game: makeGame(
            title: "Recipe Steps",
            rounds: [
                round("Prep", emoji: "🔪", color: 6, seconds: 60, countsAsPlayer: false),
                round("Simmer", emoji: "🥘", color: 1, seconds: 300, countsAsPlayer: false),
                round("Flip or Stir", emoji: "🥄", color: 2, seconds: 120, countsAsPlayer: false),
                round("Rest", emoji: "⏲️", color: 5, seconds: 180, countsAsPlayer: false),
            ]
        )
    )

    private static let plantWatering = StarterTemplate(
        id: "plant-watering",
        title: "Plant Watering",
        subtitle: "Water zones with a soak pause.",
        game: makeGame(
            title: "Plant Watering",
            rounds: [
                round("Herbs", emoji: "🌿", color: 3, seconds: 45, countsAsPlayer: false),
                round("Houseplants", emoji: "🪴", color: 4, seconds: 90, countsAsPlayer: false),
                round("Soak Pause", emoji: "💧", color: 6, seconds: 120, countsAsPlayer: false),
                round("Balcony Pots", emoji: "🌱", color: 5, seconds: 90, countsAsPlayer: false),
            ]
        )
    )

    private static let classroomStations = StarterTemplate(
        id: "classroom-stations",
        title: "Classroom Stations",
        subtitle: "Rotate groups through timed stations.",
        game: makeGame(
            title: "Classroom Stations",
            rounds: [
                round("Station 1", emoji: "📚", color: 7, seconds: 300),
                round("Station 2", emoji: "✏️", color: 8, seconds: 300),
                round("Station 3", emoji: "🧪", color: 9, seconds: 300),
                round("Clean Up", emoji: "🧹", color: 10, seconds: 120, countsAsPlayer: false),
            ]
        )
    )

    private static let meetingAgenda = StarterTemplate(
        id: "meeting-agenda",
        title: "Meeting Agenda",
        subtitle: "Keep speakers and agenda items moving.",
        game: makeGame(
            title: "Meeting Agenda",
            rounds: [
                round("Opening", emoji: "👋", color: 11, seconds: 120, countsAsPlayer: false),
                round("Updates", emoji: "📣", color: 12, seconds: 300),
                round("Discussion", emoji: "💬", color: 13, seconds: 600),
                round("Decisions", emoji: "✅", color: 14, seconds: 180, countsAsPlayer: false),
            ]
        )
    )

    private static let morningRoutine = StarterTemplate(
        id: "morning-routine",
        title: "Morning Routine",
        subtitle: "Get ready and out the door in 40 minutes.",
        game: makeGame(
            title: "Morning Routine",
            rounds: [
                round("Wake Up", emoji: Theme.Emoji.wakeUp, color: 2, seconds: 900, countsAsPlayer: false),
                round("Wash Up", emoji: Theme.Emoji.washUp, color: 6, seconds: 300, countsAsPlayer: false),
                round("Get Dressed", emoji: Theme.Emoji.getDressed, color: 7, seconds: 120, countsAsPlayer: false),
                round("Breakfast", emoji: Theme.Emoji.breakfast, color: 1, seconds: 600, countsAsPlayer: false),
                round("Brush Teeth", emoji: Theme.Emoji.brushTeeth, color: 4, seconds: 120, countsAsPlayer: false),
                round("Pack Essentials", emoji: Theme.Emoji.packEssentials, color: 8, seconds: 180, countsAsPlayer: false),
                round("Shoes & Coat", emoji: Theme.Emoji.shoesAndCoat, color: 9, seconds: 120, countsAsPlayer: false),
                round("Start Commute", emoji: Theme.Emoji.startCommute, color: 13, seconds: 60, countsAsPlayer: false),
            ]
        )
    )

    private static func makeGame(title: String, rounds: [Round]) -> GameSequence {
        var game = GameSequence(title: title, rounds: rounds, roundCount: 1)
        game.reindexRounds()
        return game
    }

    private static func round(
        _ name: String,
        emoji: String,
        color: Int,
        seconds: Int,
        countsAsPlayer: Bool = true
    ) -> Round {
        Round(
            name: name,
            color: .palette(index: color),
            sound: .chime,
            emoji: emoji,
            durationSeconds: seconds,
            startPaused: false,
            isActive: true,
            orderIndex: 0,
            countsAsPlayer: countsAsPlayer
        )
    }
}
