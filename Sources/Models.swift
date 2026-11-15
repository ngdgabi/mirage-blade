import Foundation
import CoreGraphics
import SpriteKit

// MARK: - Visual & Audio Era Modes (1989 EGA/AdLib ↔ 2026 120Hz HD Palace)

enum VisualTheme: String, Codable, CaseIterable {
    case hdOverdrive = "2026 HD PALACE"
    case crtCabinet  = "CRT ARCADE"
    case retro1989   = "1989 EGA PIXEL"

    var next: VisualTheme {
        let all = Self.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }
}

enum AudioChipMode: String, Codable, CaseIterable {
    case modernSynth = "ARABIAN SYNTH"
    case retroAdLib  = "1989 ADLIB FM"

    var next: AudioChipMode {
        self == .modernSynth ? .retroAdLib : .modernSynth
    }
}

enum SceneMode: Equatable {
    case titleMenu
    case stageSelect
    case dungeonPlay
    case duelArena
    case medalsScreen
    case howToPlay
    case settingsScreen
    case stageClear
    case victoryEnding
    case gameOver
}

enum EnemyArchetype: String, Codable, CaseIterable {
    case dungeonGuard    = "DUNGEON GUARD"
    case palaceCaptain   = "PALACE CAPTAIN"
    case skeletonKnight  = "IMMORTAL SKELETON"
    case shadowPhantom   = "MIRROR PHANTOM"
    case grandVizier     = "GRAND VIZIER ZAFAR"

    var maxHP: Int {
        switch self {
        case .dungeonGuard:   return 3
        case .palaceCaptain:  return 4
        case .skeletonKnight: return 4
        case .shadowPhantom:  return 3
        case .grandVizier:    return 6
        }
    }

    var tunicHex: UInt32 {
        switch self {
        case .dungeonGuard:   return 0x3A6BD6
        case .palaceCaptain:  return 0x9B2B48
        case .skeletonKnight: return 0xD8DFEA
        case .shadowPhantom:  return 0x45E6FF
        case .grandVizier:    return 0x6A1FB8
        }
    }

    var sashHex: UInt32 {
        switch self {
        case .dungeonGuard:   return 0xF5B942
        case .palaceCaptain:  return 0xFFD966
        case .skeletonKnight: return 0x52B788
        case .shadowPhantom:  return 0xBDF4FF
        case .grandVizier:    return 0xFF3B4E
        }
    }
}

enum HeroPose: String {
    case idle
    case runA
    case runB
    case sneak
    case jumpArc
    case ledgeHang
    case swordGuard
    case swordSlash
    case swordParry
    case drinkPotion
    case hurt
}

enum TileFeature: Equatable {
    case empty
    case solidStone
    case spikes            // Safe when sneaking/stepping; lethal on fast run or fall
    case chopper           // Rhythmic slicing steel jaws
    case looseSlab         // Shakes and drops after stepping on it
    case plateOpen(gateCol: Int, gateTier: Int)
    case portcullis(initiallyOpen: Bool)
    case exitArchway       // Opens once stage exit plate is triggered (or boss defeated)
    case potionHeal        // +1 HP
    case potionMaxLife     // +1 Max HP & Full Heal
    case potionFeather     // Slow-fall feather aura
    case scimitarPedestal  // Stage 1 iconic sword pickup!
    case magicMirror       // Stage 4 shimmering silver mirror!
}

// MARK: - Authentic 1989 EGA 16-Color & 2026 HD Arabian Nights Palette

enum Palette {
    static let egaBlack       = SKColor.hex(0x000000)
    static let egaBlue        = SKColor.hex(0x0000AA)
    static let egaGreen       = SKColor.hex(0x00AA00)
    static let egaCyan        = SKColor.hex(0x00AAAA)
    static let egaRed         = SKColor.hex(0xAA0000)
    static let egaMagenta     = SKColor.hex(0xAA00AA)
    static let egaBrown       = SKColor.hex(0xAA5500)
    static let egaLightGray   = SKColor.hex(0xAAAAAA)
    static let egaDarkGray    = SKColor.hex(0x555555)
    static let egaBrightBlue  = SKColor.hex(0x5555FF)
    static let egaBrightGreen = SKColor.hex(0x55FF55)
    static let egaBrightCyan  = SKColor.hex(0x55FFFF)
    static let egaBrightRed   = SKColor.hex(0xFF5555)
    static let egaPink        = SKColor.hex(0xFF55FF)
    static let egaYellow      = SKColor.hex(0xFFFF55)
    static let egaWhite       = SKColor.hex(0xFFFFFF)

    static let hdNightSky     = SKColor.hex(0x090D1F)
    static let hdIndigoArch   = SKColor.hex(0x141C3A)
    static let hdSandstone    = SKColor.hex(0xC9985B)
    static let hdSandstoneLit = SKColor.hex(0xE8BD7E)
    static let hdStoneShadow  = SKColor.hex(0x4E3824)
    static let hdDungeonSlate = SKColor.hex(0x2D354C)
    static let hdDungeonLit   = SKColor.hex(0x4A5678)
    static let hdGold         = SKColor.hex(0xF6C445)
    static let hdCrimson      = SKColor.hex(0xE33946)
    static let hdCyanMagic    = SKColor.hex(0x38E8FF)
    static let hdEmerald      = SKColor.hex(0x2FE388)
}

// MARK: - 6 Iconic Multi-Room Palace & Dungeon Stages

enum PalaceBiome: String, Codable {
    case sunkenDungeon   = "SUNKEN DUNGEON"
    case undeadCatacombs = "CATACOMBS OF BONE"
    case moonlitCourtyard = "MOONLIT COURTYARD"
    case mirrorHall      = "HALL OF THE MIRROR"
    case astralBridge    = "SHADOW LIGHT SPIRE"
    case vizierSanctum   = "VIZIER'S HOURGLASS"
}

struct RoomBlueprint {
    let title: String
    /// 3 vertical tiers (0 = bottom floor, 1 = middle gallery, 2 = upper rampart), each 10 columns wide (0..9)
    let grid: [[TileFeature]]
    let torches: [(col: Int, tier: Int)]
    let guardSpawn: (col: Int, tier: Int, archetype: EnemyArchetype)?
}

struct StageBlueprint {
    let number: Int
    let name: String
    let subtitle: String
    let biome: PalaceBiome
    let startsWithSword: Bool
    let rooms: [RoomBlueprint]
    let startRoom: Int
    let startCol: Int
    let startTier: Int
}

enum PalaceStageCatalog {
    static let stages: [StageBlueprint] = [
        // STAGE 1: Sunken Limestone Dungeon (Find Scimitar in Room 0/1, Loose Slab, Spikes, Jailer Guard, Exit Arch)
        StageBlueprint(
            number: 1,
            name: "THE SUNKEN DUNGEON",
            subtitle: "Claim the Golden Scimitar & Escape the Cells",
            biome: .sunkenDungeon,
            startsWithSword: false,
            rooms: [
                RoomBlueprint(
                    title: "PRISONER'S CELLBLOCK",
                    grid: [
                        // Tier 0 (Bottom)
                        [.solidStone, .solidStone, .scimitarPedestal, .solidStone, .spikes, .solidStone, .solidStone, .plateOpen(gateCol: 8, gateTier: 0), .portcullis(initiallyOpen: false), .solidStone],
                        // Tier 1 (Middle)
                        [.solidStone, .solidStone, .solidStone, .looseSlab, .empty, .empty, .solidStone, .potionHeal, .solidStone, .solidStone],
                        // Tier 2 (Upper)
                        [.solidStone, .solidStone, .empty, .empty, .solidStone, .solidStone, .solidStone, .empty, .solidStone, .solidStone]
                    ],
                    torches: [(1, 1), (6, 0), (8, 1)],
                    guardSpawn: nil
                ),
                RoomBlueprint(
                    title: "JAILER'S GATEHOUSE",
                    grid: [
                        [.solidStone, .solidStone, .spikes, .solidStone, .solidStone, .solidStone, .solidStone, .solidStone, .exitArchway, .solidStone],
                        [.solidStone, .solidStone, .empty, .solidStone, .chopper, .solidStone, .plateOpen(gateCol: 8, gateTier: 0), .solidStone, .empty, .solidStone],
                        [.solidStone, .potionMaxLife, .solidStone, .solidStone, .empty, .empty, .solidStone, .solidStone, .solidStone, .solidStone]
                    ],
                    torches: [(1, 0), (5, 0), (7, 1)],
                    guardSpawn: (col: 6, tier: 0, archetype: .dungeonGuard)
                )
            ],
            startRoom: 0, startCol: 1, startTier: 2
        ),

        // STAGE 2: Catacombs of the Undead (Chopper timing, chasm jump, Immortal Skeleton Knight!)
        StageBlueprint(
            number: 2,
            name: "CATACOMBS OF BONE",
            subtitle: "Parry the Skeleton Captain Across the Chasm",
            biome: .undeadCatacombs,
            startsWithSword: true,
            rooms: [
                RoomBlueprint(
                    title: "HALL OF GUILLOTINES",
                    grid: [
                        [.solidStone, .solidStone, .spikes, .spikes, .solidStone, .solidStone, .chopper, .solidStone, .solidStone, .solidStone],
                        [.solidStone, .solidStone, .solidStone, .empty, .empty, .solidStone, .potionHeal, .solidStone, .plateOpen(gateCol: 9, gateTier: 1), .portcullis(initiallyOpen: false)],
                        [.solidStone, .potionMaxLife, .solidStone, .looseSlab, .solidStone, .empty, .empty, .solidStone, .solidStone, .solidStone]
                    ],
                    torches: [(1, 1), (5, 1), (8, 0)],
                    guardSpawn: (col: 5, tier: 0, archetype: .dungeonGuard)
                ),
                RoomBlueprint(
                    title: "OSSUARY BRIDGE",
                    grid: [
                        [.solidStone, .spikes, .spikes, .spikes, .spikes, .spikes, .solidStone, .solidStone, .exitArchway, .solidStone],
                        [.solidStone, .solidStone, .solidStone, .empty, .solidStone, .solidStone, .solidStone, .solidStone, .empty, .solidStone],
                        [.solidStone, .empty, .solidStone, .plateOpen(gateCol: 8, gateTier: 0), .solidStone, .empty, .empty, .potionHeal, .solidStone, .solidStone]
                    ],
                    torches: [(2, 1), (6, 1), (8, 0)],
                    guardSpawn: (col: 6, tier: 1, archetype: .skeletonKnight)
                )
            ],
            startRoom: 0, startCol: 1, startTier: 1
        ),

        // STAGE 3: Moonlit Palace Courtyard (Starry arches, silk banners, Palace Captains)
        StageBlueprint(
            number: 3,
            name: "MOONLIT COURTYARD",
            subtitle: "Sprint the Starlit Terraces & Outduel the Captain",
            biome: .moonlitCourtyard,
            startsWithSword: true,
            rooms: [
                RoomBlueprint(
                    title: "SILK PAVILION TERRACE",
                    grid: [
                        [.solidStone, .solidStone, .solidStone, .spikes, .solidStone, .solidStone, .solidStone, .chopper, .solidStone, .solidStone],
                        [.solidStone, .solidStone, .empty, .empty, .solidStone, .potionHeal, .solidStone, .solidStone, .solidStone, .solidStone],
                        [.solidStone, .empty, .solidStone, .solidStone, .empty, .empty, .solidStone, .plateOpen(gateCol: 9, gateTier: 2), .solidStone, .portcullis(initiallyOpen: false)]
                    ],
                    torches: [(1, 0), (5, 1), (8, 2)],
                    guardSpawn: (col: 5, tier: 0, archetype: .palaceCaptain)
                ),
                RoomBlueprint(
                    title: "FOUNTAIN ARCHWAY",
                    grid: [
                        [.solidStone, .spikes, .solidStone, .solidStone, .solidStone, .spikes, .solidStone, .solidStone, .exitArchway, .solidStone],
                        [.solidStone, .solidStone, .solidStone, .chopper, .solidStone, .solidStone, .plateOpen(gateCol: 8, gateTier: 0), .solidStone, .empty, .solidStone],
                        [.solidStone, .solidStone, .empty, .empty, .solidStone, .potionMaxLife, .solidStone, .empty, .solidStone, .solidStone]
                    ],
                    torches: [(2, 1), (6, 1), (8, 0)],
                    guardSpawn: (col: 4, tier: 0, archetype: .palaceCaptain)
                )
            ],
            startRoom: 0, startCol: 1, startTier: 0
        ),

        // STAGE 4: Hall of the Silver Mirror (Feather-fall shaft & Magic Mirror Phantom!)
        StageBlueprint(
            number: 4,
            name: "HALL OF THE MIRROR",
            subtitle: "Leap Through Silver Glass & Face Your Reflection",
            biome: .mirrorHall,
            startsWithSword: true,
            rooms: [
                RoomBlueprint(
                    title: "EMERALD FEATHER GALLERY",
                    grid: [
                        [.solidStone, .solidStone, .spikes, .solidStone, .solidStone, .chopper, .solidStone, .solidStone, .solidStone, .solidStone],
                        [.solidStone, .potionFeather, .empty, .solidStone, .solidStone, .empty, .solidStone, .plateOpen(gateCol: 9, gateTier: 1), .solidStone, .portcullis(initiallyOpen: false)],
                        [.solidStone, .solidStone, .solidStone, .looseSlab, .empty, .solidStone, .potionHeal, .solidStone, .solidStone, .solidStone]
                    ],
                    torches: [(1, 2), (4, 1), (7, 1)],
                    guardSpawn: (col: 7, tier: 0, archetype: .palaceCaptain)
                ),
                RoomBlueprint(
                    title: "CHAMBER OF REFLECTIONS",
                    grid: [
                        [.solidStone, .solidStone, .spikes, .spikes, .solidStone, .solidStone, .solidStone, .solidStone, .exitArchway, .solidStone],
                        [.solidStone, .solidStone, .solidStone, .empty, .magicMirror, .solidStone, .plateOpen(gateCol: 8, gateTier: 0), .solidStone, .empty, .solidStone],
                        [.solidStone, .empty, .solidStone, .solidStone, .empty, .empty, .solidStone, .potionMaxLife, .solidStone, .solidStone]
                    ],
                    torches: [(2, 1), (6, 1), (8, 0)],
                    guardSpawn: nil
                )
            ],
            startRoom: 0, startCol: 1, startTier: 2
        ),

        // STAGE 5: Shadow Bridge & Astral Spire
        StageBlueprint(
            number: 5,
            name: "SHADOW LIGHT SPIRE",
            subtitle: "Sheathe Your Blade & Reunite With Your Phantom",
            biome: .astralBridge,
            startsWithSword: true,
            rooms: [
                RoomBlueprint(
                    title: "ASTRAL RAMPART",
                    grid: [
                        [.solidStone, .spikes, .spikes, .solidStone, .solidStone, .chopper, .solidStone, .spikes, .solidStone, .solidStone],
                        [.solidStone, .solidStone, .empty, .solidStone, .potionHeal, .solidStone, .solidStone, .empty, .solidStone, .solidStone],
                        [.solidStone, .empty, .solidStone, .solidStone, .empty, .solidStone, .plateOpen(gateCol: 9, gateTier: 2), .solidStone, .solidStone, .portcullis(initiallyOpen: false)]
                    ],
                    torches: [(1, 1), (4, 1), (8, 2)],
                    guardSpawn: (col: 4, tier: 0, archetype: .palaceCaptain)
                ),
                RoomBlueprint(
                    title: "LUMINOUS CHASM BRIDGE",
                    grid: [
                        [.solidStone, .spikes, .spikes, .spikes, .spikes, .spikes, .solidStone, .solidStone, .exitArchway, .solidStone],
                        [.solidStone, .solidStone, .solidStone, .solidStone, .solidStone, .solidStone, .plateOpen(gateCol: 8, gateTier: 0), .solidStone, .empty, .solidStone],
                        [.solidStone, .solidStone, .empty, .empty, .empty, .empty, .solidStone, .potionMaxLife, .solidStone, .solidStone]
                    ],
                    torches: [(2, 1), (6, 1), (8, 0)],
                    guardSpawn: (col: 5, tier: 1, archetype: .shadowPhantom)
                )
            ],
            startRoom: 0, startCol: 1, startTier: 1
        ),

        // STAGE 6: Grand Vizier Zafar's Hourglass Sanctum
        StageBlueprint(
            number: 6,
            name: "VIZIER'S HOURGLASS",
            subtitle: "Defeat Grand Vizier Zafar Before the Final Grain Falls",
            biome: .vizierSanctum,
            startsWithSword: true,
            rooms: [
                RoomBlueprint(
                    title: "SANCTUM ANTECHAMBER",
                    grid: [
                        [.solidStone, .solidStone, .chopper, .solidStone, .spikes, .solidStone, .chopper, .solidStone, .solidStone, .solidStone],
                        [.solidStone, .potionMaxLife, .solidStone, .solidStone, .empty, .solidStone, .potionHeal, .solidStone, .plateOpen(gateCol: 9, gateTier: 1), .portcullis(initiallyOpen: false)],
                        [.solidStone, .empty, .empty, .solidStone, .solidStone, .empty, .empty, .solidStone, .solidStone, .solidStone]
                    ],
                    torches: [(1, 1), (5, 0), (8, 1)],
                    guardSpawn: (col: 5, tier: 0, archetype: .palaceCaptain)
                ),
                RoomBlueprint(
                    title: "THRONE OF THE HOURGLASS",
                    grid: [
                        [.solidStone, .spikes, .solidStone, .solidStone, .solidStone, .solidStone, .solidStone, .spikes, .exitArchway, .solidStone],
                        [.solidStone, .solidStone, .empty, .empty, .empty, .empty, .empty, .solidStone, .empty, .solidStone],
                        [.solidStone, .empty, .solidStone, .solidStone, .empty, .solidStone, .solidStone, .empty, .solidStone, .solidStone]
                    ],
                    torches: [(2, 0), (6, 0), (8, 0)],
                    guardSpawn: (col: 6, tier: 0, archetype: .grandVizier)
                )
            ],
            startRoom: 0, startCol: 1, startTier: 0
        )
    ]
}

// MARK: - 12 Royal Seals (Achievements) & Local Persistence

struct RoyalSeal: Identifiable {
    let id: String
    let title: String
    let subtitle: String
}

enum RoyalSealCatalog {
    static let all: [RoyalSeal] = [
        RoyalSeal(id: "first_blade",   title: "GOLDEN SCIMITAR",    subtitle: "Claim the curved blade in the Sunken Dungeon"),
        RoyalSeal(id: "perfect_parry", title: "STEEL RIPOSTE",      subtitle: "Parry an enemy strike and land a counter-slash"),
        RoyalSeal(id: "trap_whisper",  title: "SILENT SANDALS",     subtitle: "Sneak safely across concealed floor spikes"),
        RoyalSeal(id: "chopper_dash",  title: "BLADE DANCER",       subtitle: "Dash cleanly through slicing steel jaws"),
        RoyalSeal(id: "bone_breaker",  title: "BONE SHATTERER",     subtitle: "Knock the Skeleton Captain into the chasm"),
        RoyalSeal(id: "life_amphora",  title: "VESSEL OF VITALITY", subtitle: "Drink a Golden Amphora to expand maximum health"),
        RoyalSeal(id: "feather_leap",  title: "EMERALD MIRAGE",     subtitle: "Float gently with the Emerald Feather Elixir"),
        RoyalSeal(id: "mirror_soul",   title: "SILVER REFLECTION",  subtitle: "Leap through the Magic Mirror"),
        RoyalSeal(id: "vizier_fall",   title: "SHATTERED HOURGLASS", subtitle: "Defeat Grand Vizier Zafar and save the palace"),
        RoyalSeal(id: "speed_30",      title: "SANDSTORM RUNNER",   subtitle: "Complete the palace escape with 40+ minutes left"),
        RoyalSeal(id: "duel_master",   title: "CHAMPION OF BLADES", subtitle: "Win 5 consecutive bouts in Quick Scimitar Duel"),
        RoyalSeal(id: "era_traveler",  title: "1989 TIME TRAVELER", subtitle: "Play in 1989 EGA Pixel & AdLib FM Chiptune mode")
    ]
}

struct PlayerSettings: Codable {
    var visualTheme: VisualTheme = .hdOverdrive
    var audioChip: AudioChipMode = .modernSynth
    var relaxedHourglass: Bool = false
    var launchFullscreen: Bool = false
    var masterVolume: Float = 0.85
}

struct SaveData: Codable {
    var settings: PlayerSettings = PlayerSettings()
    var unlockedStages: Int = 6
    var bestEscapeSecondsUsed: Int? = nil
    var highestDuelStreak: Int = 0
    var totalGuardsDefeated: Int = 0
    var unlockedSeals: Set<String> = []
}

@MainActor
final class PersistenceManager {
    static let shared = PersistenceManager()
    private let key = "com.ngd.mirageblade.savedata.v1"
    private(set) var data: SaveData

    private init() {
        if let raw = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(SaveData.self, from: raw) {
            self.data = decoded
        } else {
            self.data = SaveData()
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    func updateSettings(_ block: (inout PlayerSettings) -> Void) {
        block(&data.settings)
        save()
    }

    @discardableResult
    func unlockSeal(_ id: String) -> Bool {
        guard !data.unlockedSeals.contains(id) else { return false }
        data.unlockedSeals.insert(id)
        save()
        return true
    }

    func recordDefeat() {
        data.totalGuardsDefeated += 1
        save()
    }

    func recordDuelStreak(_ streak: Int) {
        if streak > data.highestDuelStreak {
            data.highestDuelStreak = streak
        }
        if streak >= 5 {
            _ = unlockSeal("duel_master")
        }
        save()
    }

    func recordVictory(secondsUsed: Int) {
        if let prev = data.bestEscapeSecondsUsed {
            if secondsUsed < prev { data.bestEscapeSecondsUsed = secondsUsed }
        } else {
            data.bestEscapeSecondsUsed = secondsUsed
        }
        _ = unlockSeal("vizier_fall")
        if secondsUsed <= 20 * 60 {
            _ = unlockSeal("speed_30")
        }
        save()
    }
}
