
enum IconCategory: String, CaseIterable {
    case fitness = "Fitness"
    case wellness = "Wellness"
    case learning = "Learning"
    case creative = "Creative"
    case productivity = "Productivity"
    case home = "Home"
    case social = "Social"
    case nature = "Nature"
    
    var name: String { rawValue }
    
    var icon: String {
        switch self {
        case .fitness: return "figure.run"
        case .wellness: return "heart.fill"
        case .learning: return "book.fill"
        case .creative: return "paintbrush.fill"
        case .productivity: return "checkmark.circle.fill"
        case .home: return "house.fill"
        case .social: return "person.2.fill"
        case .nature: return "leaf.fill"
        }
    }
    
    var icons: [String] {
        switch self {
        case .fitness:
            return [
                "figure.run", "figure.walk", "figure.yoga", "figure.cooldown",
                "figure.strengthtraining.traditional", "dumbbell.fill", "figure.dance",
                "figure.jumprope", "figure.boxing", "figure.kickboxing",
                "figure.basketball", "figure.soccer", "figure.tennis",
                "figure.baseball", "figure.volleyball", "figure.badminton",
                "figure.skiing.downhill", "figure.snowboarding", "figure.surfing",
                "bicycle", "figure.outdoor.cycle", "figure.indoor.cycle",
                "figure.pool.swim", "figure.water.fitness", "figure.rowing",
                "figure.climbing", "figure.hiking", "shoeprints.fill",
                "heart.circle.fill", "bolt.heart.fill", "stopwatch.fill"
            ]
        case .wellness:
            return [
                "heart.fill", "heart.circle.fill", "sparkles",
                "leaf.fill", "drop.fill", "wind",
                "sun.max.fill", "moon.stars.fill", "cloud.sun.fill",
                "bed.double.fill", "zzz", "waterbottle.fill",
                "brain.fill", "lungs.fill", "figure.mind.and.body",
                "pills.fill", "cross.vial.fill", "stethoscope",
                "medical.thermometer.fill", "bandage.fill", "cross.case.fill",
                "allergens", "syringe.fill", "ivfluid.bag.fill"
            ]
        case .learning:
            return [
                "book.fill", "book.closed.fill", "books.vertical.fill",
                "magazine.fill", "newspaper.fill", "note.text",
                "doc.text.fill", "doc.richtext.fill", "note",
                "pencil", "pencil.circle.fill", "highlighter",
                "graduationcap.fill", "studentdesk", "backpack.fill",
                "brain.head.profile", "lightbulb.fill", "star.fill",
                "chart.bar.fill", "text.book.closed.fill", "character.book.closed.fill",
                "abc", "textformat.abc", "textformat.123"
            ]
        case .creative:
            return [
                "paintbrush.fill", "paintpalette.fill", "photo.fill",
                "camera.fill", "video.fill", "film.fill",
                "music.note", "music.note.list", "guitars.fill",
                "pianokeys.inverse", "mic.fill", "waveform",
                "scissors", "pencil.and.ruler.fill", "square.and.pencil",
                "paintbrush.pointed.fill", "eyedropper.halffull", "swatchpalette.fill",
                "lasso.badge.sparkles", "photo.badge.plus.fill", "rectangle.portrait.on.rectangle.portrait.fill"
            ]
        case .productivity:
            return [
                "checkmark.circle.fill", "checkmark.square.fill", "list.bullet",
                "list.bullet.clipboard.fill", "calendar", "clock.fill",
                "timer", "stopwatch.fill", "bell.fill",
                "flag.fill", "star.fill", "paperclip",
                "folder.fill", "doc.fill", "tray.fill",
                "archivebox.fill", "shippingbox.fill", "envelope.fill",
                "paperplane.fill", "link", "square.grid.2x2.fill",
                "target", "scope", "chart.line.uptrend.xyaxis"
            ]
        case .home:
            return [
                "house.fill", "door.left.hand.closed", "lightbulb.fill",
                "lamp.desk.fill", "lamp.floor.fill", "lamp.ceiling.fill",
                "fan.fill", "poweroutlet.type.a.fill", "heater.vertical.fill",
                "basket.fill", "cart.fill", "bag.fill",
                "fork.knife", "cup.and.saucer.fill", "mug.fill",
                "refrigerator.fill", "stove.fill", "oven.fill",
                "washer.fill", "dryer.fill", "dishwasher.fill",
                "trash.fill", "toilet.fill", "shower.fill",
                "bathtub.fill", "bed.double.fill", "sofa.fill",
                "chair.fill", "table.furniture.fill", "cabinet.fill"
            ]
        case .social:
            return [
                "person.fill", "person.2.fill", "person.3.fill",
                "person.crop.circle.fill", "person.crop.square.fill", "person.and.background.dotted",
                "bubble.fill", "bubble.left.and.bubble.right.fill", "message.fill",
                "phone.fill", "video.fill", "envelope.fill",
                "heart.fill", "hand.thumbsup.fill", "star.fill",
                "gift.fill", "party.popper.fill", "balloon.fill",
                "birthday.cake.fill", "cup.and.saucer.fill", "wineglass.fill",
                "camera.fill", "camera.viewfinder", "photo.on.rectangle.fill"
            ]
        case .nature:
            return [
                "leaf.fill", "tree.fill", "flower.fill",
                "sun.max.fill", "cloud.sun.fill", "cloud.rain.fill",
                "snowflake", "wind", "tornado",
                "flame.fill", "drop.fill", "globe.americas.fill",
                "mountain.2.fill", "beach.umbrella.fill", "water.waves",
                "pawprint.fill", "hare.fill", "bird.fill",
                "fish.fill", "ladybug.fill", "ant.fill",
                "tortoise.fill", "lizard.fill", "cat.fill",
                "dog.fill", "carrot.fill", "leaf.arrow.triangle.circlepath"
            ]
        }
    }
}