/// The eight menu bar designs available in Settings.
/// Raw values are saved in UserDefaults, so keep them stable.
enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case plainWhale
    case spoutWhale
    case boldWhale
    case deepSeekPlain
    case deepSeekTwoTone
    case tailSplash
    case oceanWave
    case hourglass

    var id: Self { self }

    var displayName: String {
        switch self {
        case .plainWhale: return "Plain whale"
        case .spoutWhale: return "Spout whale"
        case .boldWhale: return "Bold whale"
        case .deepSeekPlain: return "DeepSeek plain"
        case .deepSeekTwoTone: return "DeepSeek two-tone"
        case .tailSplash: return "Tail splash"
        case .oceanWave: return "Ocean wave"
        case .hourglass: return "Hourglass"
        }
    }

    var shortName: String {
        switch self {
        case .plainWhale: return "Plain"
        case .spoutWhale: return "Spout"
        case .boldWhale: return "Bold"
        case .deepSeekPlain: return "DeepSeek"
        case .deepSeekTwoTone: return "Two-tone"
        case .tailSplash: return "Tail"
        case .oceanWave: return "Wave"
        case .hourglass: return "Hourglass"
        }
    }

    var showsPricingColor: Bool {
        self != .plainWhale && self != .deepSeekPlain
    }
}
