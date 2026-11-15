import Foundation
import CoreGraphics

struct LooseTileState {
    var room: Int
    var tier: Int
    var col: Int
    var timer: CGFloat = 0
    var falling: Bool = false
    var fallenY: CGFloat = 0
    var gone: Bool = false
}

struct GateState {
    var room: Int
    var tier: Int
    var col: Int
    var openRatio: CGFloat
    var holdTimer: CGFloat
}

struct ActiveEnemy {
    var room: Int
    var tier: Int
    var x: CGFloat
    var facing: CGFloat = -1
    var archetype: EnemyArchetype
    var hp: Int
    var maxHP: Int
    var pose: HeroPose = .swordGuard
    var aiTimer: CGFloat = 0.6
    var actionTimer: CGFloat = 0
    var staggerTimer: CGFloat = 0
    var downTimer: CGFloat = 0 // Skeleton reassembly timer
    var defeated: Bool = false
}

enum DungeonEvent {
    case playSFX(SoundEffect)
    case banner(String, UInt32)
    case spark(CGPoint, UInt32)
    case shake(CGFloat)
    case stageCleared
    case campaignWon
    case heroDied(String)
}

@MainActor
final class DungeonEngine {
    // Universal Safe Box geometry: 10 columns x 96pt = 960pt centered at x: 160..1120
    static let gridLeft: CGFloat = 160.0
    static let colWidth: CGFloat = 96.0
    static let tierHeights: [CGFloat] = [178.0, 338.0, 498.0]

    var stage: StageBlueprint
    var mutableRooms: [[[TileFeature]]] = []
    var currentRoom: Int = 0

    // Hero state
    var heroX: CGFloat = 256
    var heroY: CGFloat = 178
    var heroVX: CGFloat = 0
    var heroVY: CGFloat = 0
    var heroFacing: CGFloat = 1
    var heroGrounded: Bool = true
    var heroHasSword: Bool = true
    var heroHP: Int = 3
    var heroMaxHP: Int = 3
    var heroPose: HeroPose = .idle
    var featherTimer: CGFloat = 0
    var attackTimer: CGFloat = 0
    var parryTimer: CGFloat = 0
    var riposteWindow: CGFloat = 0
    var hurtTimer: CGFloat = 0
    var hangTimer: CGFloat = 0
    var hangTargetY: CGFloat = 0
    var runCycle: CGFloat = 0
    var stepSFXCooldown: CGFloat = 0

    // Hourglass timer (60 minutes = 3600s)
    var remainingSeconds: Double = 3600.0
    var elapsedSeconds: Double = 0
    var chopperClock: CGFloat = 0
    var exitUnlocked: Bool = false
    var isDuelArenaMode: Bool = false
    var duelBoutNumber: Int = 1
    var duelStreak: Int = 0

    var gates: [GateState] = []
    var looseTiles: [LooseTileState] = []
    var enemies: [ActiveEnemy] = []
    private var gateTickAccum: CGFloat = 0

    init(stageIndex: Int = 0, carryMaxHP: Int = 3) {
        let clamped = max(0, min(PalaceStageCatalog.stages.count - 1, stageIndex))
        self.stage = PalaceStageCatalog.stages[clamped]
        self.heroMaxHP = max(3, carryMaxHP)
        self.heroHP = self.heroMaxHP
        loadStage(stageIndex: clamped, preserveHealth: true)
    }

    static func colCenterX(_ col: Int) -> CGFloat {
        gridLeft + (CGFloat(col) + 0.5) * colWidth
    }

    static func colIndex(forX x: CGFloat) -> Int {
        max(0, min(9, Int((x - gridLeft) / colWidth)))
    }

    static func tierY(_ tier: Int) -> CGFloat {
        tierHeights[max(0, min(2, tier))]
    }

    func loadStage(stageIndex: Int, preserveHealth: Bool) {
        let clamped = max(0, min(PalaceStageCatalog.stages.count - 1, stageIndex))
        self.stage = PalaceStageCatalog.stages[clamped]
        self.isDuelArenaMode = false
        self.mutableRooms = stage.rooms.map { $0.grid }
        self.currentRoom = stage.startRoom
        self.heroX = Self.colCenterX(stage.startCol)
        self.heroY = Self.tierY(stage.startTier)
        self.heroVX = 0
        self.heroVY = 0
        self.heroFacing = 1
        self.heroGrounded = true
        self.heroHasSword = stage.startsWithSword
        if !preserveHealth {
            self.heroMaxHP = 3
        }
        self.heroHP = self.heroMaxHP
        self.heroPose = .idle
        self.featherTimer = 0
        self.attackTimer = 0
        self.parryTimer = 0
        self.riposteWindow = 0
        self.hurtTimer = 0
        self.hangTimer = 0
        self.exitUnlocked = (stage.number == 6) // Vizier sanctum unlocks exit on boss defeat

        gates.removeAll()
        looseTiles.removeAll()
        enemies.removeAll()

        for (rIdx, room) in stage.rooms.enumerated() {
            for t in 0..<3 {
                for c in 0..<10 {
                    switch room.grid[t][c] {
                    case .portcullis(let initiallyOpen):
                        gates.append(GateState(room: rIdx, tier: t, col: c, openRatio: initiallyOpen ? 1.0 : 0.0, holdTimer: 0))
                    case .looseSlab:
                        looseTiles.append(LooseTileState(room: rIdx, tier: t, col: c))
                    default:
                        break
                    }
                }
            }
            if let sp = room.guardSpawn {
                enemies.append(ActiveEnemy(
                    room: rIdx,
                    tier: sp.tier,
                    x: Self.colCenterX(sp.col),
                    facing: -1,
                    archetype: sp.archetype,
                    hp: sp.archetype.maxHP,
                    maxHP: sp.archetype.maxHP
                ))
            }
        }
    }

    func setupQuickDuelBout(bout: Int) {
        self.isDuelArenaMode = true
        self.duelBoutNumber = bout
        self.stage = PalaceStageCatalog.stages[2] // Moonlit Courtyard arena backdrop
        let arenaRow: [TileFeature] = [.solidStone, .spikes, .solidStone, .solidStone, .solidStone, .solidStone, .solidStone, .solidStone, .spikes, .solidStone]
        let upperRow: [TileFeature] = [.solidStone, .empty, .empty, .empty, .empty, .empty, .empty, .empty, .empty, .solidStone]
        self.mutableRooms = [[arenaRow, upperRow, upperRow]]
        self.currentRoom = 0
        self.heroX = Self.colCenterX(3)
        self.heroY = Self.tierY(0)
        self.heroVX = 0
        self.heroVY = 0
        self.heroFacing = 1
        self.heroGrounded = true
        self.heroHasSword = true
        self.heroMaxHP = 4
        self.heroHP = 4
        self.gates.removeAll()
        self.looseTiles.removeAll()

        let order: [EnemyArchetype] = [.dungeonGuard, .palaceCaptain, .skeletonKnight, .shadowPhantom, .grandVizier]
        let arch = order[(max(1, bout) - 1) % order.count]
        self.enemies = [
            ActiveEnemy(
                room: 0,
                tier: 0,
                x: Self.colCenterX(6),
                facing: -1,
                archetype: arch,
                hp: arch.maxHP,
                maxHP: arch.maxHP
            )
        ]
    }

    func tileAt(room: Int, tier: Int, col: Int) -> TileFeature {
        guard room >= 0, room < mutableRooms.count, tier >= 0, tier < 3, col >= 0, col < 10 else {
            return .solidStone
        }
        if let lt = looseTiles.first(where: { $0.room == room && $0.tier == tier && $0.col == col }), (lt.falling || lt.gone) {
            return .empty
        }
        return mutableRooms[room][tier][col]
    }

    func hasFloorSupport(room: Int, tier: Int, col: Int) -> Bool {
        let f = tileAt(room: room, tier: tier, col: col)
        return f != .empty
    }

    func chopperClosedRatio(col: Int) -> CGFloat {
        let phase = (chopperClock + CGFloat(col) * 0.37).truncatingRemainder(dividingBy: 1.85) / 1.85
        // Quick lethal snap between 0.42..0.62, wide open otherwise
        if phase < 0.38 { return 0.0 }
        if phase < 0.50 { return (phase - 0.38) / 0.12 }
        if phase < 0.58 { return 1.0 }
        if phase < 0.76 { return 1.0 - (phase - 0.58) / 0.18 }
        return 0.0
    }

    func activeEnemyInCurrentRoom() -> ActiveEnemy? {
        enemies.first { $0.room == currentRoom && !$0.defeated && $0.downTimer <= 0 }
    }

    // MARK: - Deterministic 60Hz/120Hz Step

    func step(
        dt rawDT: CGFloat,
        moveX: CGFloat,
        moveY: CGFloat,
        sneakHeld: Bool,
        strikePressed: Bool,
        jumpOrParryPressed: Bool,
        relaxedTimer: Bool
    ) -> [DungeonEvent] {
        let dt = min(rawDT, 1.0 / 30.0)
        var events: [DungeonEvent] = []

        if !relaxedTimer && !isDuelArenaMode {
            remainingSeconds = max(0, remainingSeconds - Double(dt))
            if remainingSeconds <= 0 {
                events.append(.heroDied("THE FINAL GRAIN OF SAND HAS FALLEN!"))
                return events
            }
        }
        elapsedSeconds += Double(dt)

        let prevChopperClosed = (0..<10).map { chopperClosedRatio(col: $0) > 0.92 }
        chopperClock += dt
        for c in 0..<10 {
            if !prevChopperClosed[c] && chopperClosedRatio(col: c) > 0.92 {
                if mutableRooms[currentRoom].contains(where: { $0[c] == .chopper }) {
                    events.append(.playSFX(.chopperSnap))
                }
            }
        }

        if featherTimer > 0 { featherTimer = max(0, featherTimer - dt) }
        if attackTimer > 0 { attackTimer = max(0, attackTimer - dt) }
        if parryTimer > 0 { parryTimer = max(0, parryTimer - dt) }
        if riposteWindow > 0 { riposteWindow = max(0, riposteWindow - dt) }
        if hurtTimer > 0 { hurtTimer = max(0, hurtTimer - dt) }
        if stepSFXCooldown > 0 { stepSFXCooldown = max(0, stepSFXCooldown - dt) }

        // Update Portcullis Gates
        gateTickAccum += dt
        for i in gates.indices {
            if gates[i].holdTimer > 0 {
                gates[i].holdTimer -= dt
                gates[i].openRatio = min(1.0, gates[i].openRatio + dt * 2.6)
                if gates[i].room == currentRoom && gateTickAccum > 0.55 {
                    gateTickAccum = 0
                    events.append(.playSFX(.gateTick))
                }
            } else if !exitUnlocked {
                gates[i].openRatio = max(0.0, gates[i].openRatio - dt * 0.28)
            }
        }

        // Update Loose Falling Slabs
        for i in looseTiles.indices where !looseTiles[i].gone {
            if looseTiles[i].falling {
                looseTiles[i].fallenY -= 420.0 * dt
                if looseTiles[i].fallenY < -155 {
                    looseTiles[i].gone = true
                    events.append(.playSFX(.looseSlabCrash))
                    events.append(.shake(5.0))
                }
            } else if looseTiles[i].timer > 0 {
                looseTiles[i].timer += dt
                if looseTiles[i].timer > 0.42 {
                    looseTiles[i].falling = true
                }
            }
        }

        // Ledge Hang pull-up animation
        if hangTimer > 0 {
            hangTimer -= dt
            heroPose = .ledgeHang
            heroVX = 0
            heroVY = 0
            if hangTimer <= 0 {
                heroY = hangTargetY
                heroGrounded = true
                heroPose = .idle
            }
            return events
        }

        // Check if dueling an enemy on the same floor tier
        let heroTier = nearestTier(forY: heroY)
        let duelingIdx = enemies.firstIndex {
            $0.room == currentRoom && !$0.defeated && $0.downTimer <= 0 &&
            $0.tier == heroTier && abs($0.x - heroX) < 280 && heroGrounded
        }
        let inSwordCombat = (duelingIdx != nil && heroHasSword)

        if let eIdx = duelingIdx, heroHasSword {
            // Face opponent automatically
            heroFacing = (enemies[eIdx].x >= heroX) ? 1 : -1
        } else if abs(moveX) > 0.15 {
            heroFacing = (moveX > 0) ? 1 : -1
        }

        // Combat Actions (Slash & Parry)
        if inSwordCombat, let eIdx = duelingIdx {
            if jumpOrParryPressed && parryTimer <= 0 {
                parryTimer = 0.34
                heroPose = .swordParry
                events.append(.playSFX(.swordSlash))
            } else if strikePressed && attackTimer <= 0 {
                attackTimer = 0.28
                heroPose = .swordSlash
                events.append(.playSFX(.swordSlash))

                let dist = abs(enemies[eIdx].x - heroX)
                if dist < 96 {
                    let enemyBlocking = (enemies[eIdx].staggerTimer <= 0 && riposteWindow <= 0 && enemies[eIdx].archetype == .grandVizier && enemies[eIdx].actionTimer <= 0 && Int(elapsedSeconds * 7) % 3 == 0)
                    if enemyBlocking {
                        events.append(.playSFX(.swordParry))
                        events.append(.spark(CGPoint(x: (heroX + enemies[eIdx].x) * 0.5, y: heroY + 46), 0xFFD966))
                    } else {
                        let dmg = (riposteWindow > 0) ? 2 : 1
                        if riposteWindow > 0 {
                            _ = PersistenceManager.shared.unlockSeal("perfect_parry")
                            events.append(.banner("STEEL RIPOSTE!", 0xFFD966))
                            riposteWindow = 0
                        }
                        enemies[eIdx].hp -= dmg
                        enemies[eIdx].staggerTimer = 0.35
                        enemies[eIdx].x += heroFacing * 34.0
                        events.append(.playSFX(.swordHit))
                        events.append(.spark(CGPoint(x: enemies[eIdx].x, y: heroY + 44), 0xFF5252))
                        events.append(contentsOf: checkEnemyAfterHit(index: eIdx))
                    }
                }
            }
        }

        // Horizontal Movement
        if heroGrounded {
            let speed: CGFloat
            if inSwordCombat {
                speed = 135.0
            } else if sneakHeld {
                speed = 92.0
            } else {
                speed = 255.0
            }
            let desiredVX = moveX * speed

            // Careful sneak stops cleanly at pit edges!
            var blockedByEdge = false
            if sneakHeld && abs(desiredVX) > 1 {
                let probeX = heroX + (desiredVX > 0 ? 28 : -28)
                let probeCol = Self.colIndex(forX: probeX)
                if !hasFloorSupport(room: currentRoom, tier: heroTier, col: probeCol) {
                    blockedByEdge = true
                }
            }

            // Blocked by closed portcullis gate?
            let nextX = heroX + desiredVX * dt
            let blockedByGate = gates.contains { g in
                g.room == currentRoom && g.tier == heroTier && g.openRatio < 0.62 &&
                abs(Self.colCenterX(g.col) - nextX) < 26
            }

            if !blockedByEdge && !blockedByGate && attackTimer <= 0 {
                heroVX = desiredVX
                heroX += heroVX * dt
            } else {
                heroVX = 0
            }

            // Climb down ledge if pressing Down near an open gap
            if moveY < -0.55 && heroTier > 0 && !inSwordCombat {
                let col = Self.colIndex(forX: heroX)
                for adj in [col, max(0, col - 1), min(9, col + 1)] {
                    if !hasFloorSupport(room: currentRoom, tier: heroTier, col: adj) {
                        heroX = Self.colCenterX(adj)
                        heroGrounded = false
                        heroVY = -40
                        events.append(.playSFX(.ledgeGrab))
                        break
                    }
                }
            }

            // Jump or Ledge Climb Up!
            if (jumpOrParryPressed || (moveY > 0.65 && !inSwordCombat)) && !inSwordCombat {
                let col = Self.colIndex(forX: heroX)
                // Check if jumping straight up to grab an upper ledge right above an opening!
                if abs(moveX) < 0.25 && heroTier < 2 {
                    let aboveHere = hasFloorSupport(room: currentRoom, tier: heroTier + 1, col: col)
                    let leftLedge = col > 0 && hasFloorSupport(room: currentRoom, tier: heroTier + 1, col: col - 1)
                    let rightLedge = col < 9 && hasFloorSupport(room: currentRoom, tier: heroTier + 1, col: col + 1)
                    if !aboveHere && (leftLedge || rightLedge) {
                        let targetCol = (heroFacing > 0 && rightLedge) ? (col + 1) : (leftLedge ? (col - 1) : (col + 1))
                        heroX = Self.colCenterX(targetCol)
                        heroY = Self.tierY(heroTier + 1) - 42
                        hangTargetY = Self.tierY(heroTier + 1)
                        hangTimer = 0.28
                        heroPose = .ledgeHang
                        events.append(.playSFX(.ledgeGrab))
                        return events
                    }
                }
                // Running or standing broad leap!
                heroGrounded = false
                heroVY = 505.0
                heroVX = (abs(moveX) > 0.15 ? (moveX > 0 ? 1 : -1) * 285.0 : heroFacing * 190.0)
                events.append(.playSFX(.jump))
            }
        } else {
            // Airborne physics + mid-air Ledge Grab!
            let gravity: CGFloat = (featherTimer > 0 && heroVY < 0) ? 260.0 : 1180.0
            let prevY = heroY
            heroVY -= gravity * dt
            heroX += heroVX * dt
            heroY += heroVY * dt

            // Mid-air ledge grab if catching a stone lip!
            let col = Self.colIndex(forX: heroX)
            for t in 1...2 {
                let ty = Self.tierY(t)
                if abs(heroY - (ty - 28)) < 24 && heroVY < 120 && hasFloorSupport(room: currentRoom, tier: t, col: col) {
                    let prevCol = Self.colIndex(forX: heroX - heroVX * dt * 2.0)
                    if !hasFloorSupport(room: currentRoom, tier: t, col: prevCol) {
                        heroY = ty - 38
                        hangTargetY = ty
                        hangTimer = 0.24
                        heroVX = 0
                        heroVY = 0
                        heroPose = .ledgeHang
                        events.append(.playSFX(.ledgeGrab))
                        return events
                    }
                }
            }

            // Landing check across tiers
            if heroVY <= 0 {
                for t in (0...2).reversed() {
                    let ty = Self.tierY(t)
                    if prevY >= ty - 8 && heroY <= ty && hasFloorSupport(room: currentRoom, tier: t, col: col) {
                        let impactSpeed = abs(heroVY)
                        heroY = ty
                        heroVY = 0
                        heroGrounded = true
                        events.append(.playSFX(.footstep))
                        if impactSpeed > 720 && featherTimer <= 0 {
                            events.append(contentsOf: damageHero(amount: 1, reason: "CRUSHING FALL!"))
                        }
                        // Falling straight onto spikes springs them immediately!
                        if tileAt(room: currentRoom, tier: t, col: col) == .spikes {
                            events.append(.playSFX(.spikeSpring))
                            events.append(contentsOf: damageHero(amount: 2, reason: "IMPALED ON FLOOR SPIKES!"))
                        }
                        break
                    }
                }
            }

            if heroY < 40 {
                events.append(contentsOf: damageHero(amount: heroHP, reason: "FELL INTO THE ABYSS!"))
                return events
            }
        }

        // Room Screen Transitions (Left / Right)
        if heroX > Self.gridLeft + 10 * Self.colWidth - 14 {
            if currentRoom + 1 < mutableRooms.count {
                currentRoom += 1
                heroX = Self.gridLeft + 26
            } else {
                heroX = Self.gridLeft + 10 * Self.colWidth - 16
            }
        } else if heroX < Self.gridLeft + 14 {
            if currentRoom > 0 {
                currentRoom -= 1
                heroX = Self.gridLeft + 10 * Self.colWidth - 26
            } else {
                heroX = Self.gridLeft + 16
            }
        }

        // Ground Tile Interactions (Spikes, Choppers, Plates, Loose Slabs, Potions, Mirror, Exit!)
        if heroGrounded {
            let tier = nearestTier(forY: heroY)
            let col = Self.colIndex(forX: heroX)
            let feat = tileAt(room: currentRoom, tier: tier, col: col)

            if !hasFloorSupport(room: currentRoom, tier: tier, col: col) {
                heroGrounded = false
            } else {
                switch feat {
                case .spikes:
                    if abs(heroVX) > 140 && !sneakHeld && hurtTimer <= 0 {
                        events.append(.playSFX(.spikeSpring))
                        events.append(contentsOf: damageHero(amount: 1, reason: "FLOOR SPIKES! HOLD SNEAK TO PASS!"))
                    } else if abs(heroVX) > 10 && sneakHeld {
                        _ = PersistenceManager.shared.unlockSeal("trap_whisper")
                    }

                case .chopper:
                    let closed = chopperClosedRatio(col: col)
                    let centerDist = abs(heroX - Self.colCenterX(col))
                    if closed > 0.72 && centerDist < 22 && hurtTimer <= 0 {
                        events.append(.playSFX(.chopperSnap))
                        events.append(contentsOf: damageHero(amount: 2, reason: "CAUGHT IN THE SLICING JAWS!"))
                    } else if closed < 0.25 && abs(heroVX) > 150 {
                        _ = PersistenceManager.shared.unlockSeal("chopper_dash")
                    }

                case .looseSlab:
                    if let idx = looseTiles.firstIndex(where: { $0.room == currentRoom && $0.tier == tier && $0.col == col }),
                       looseTiles[idx].timer == 0 {
                        looseTiles[idx].timer = 0.01
                        events.append(.playSFX(.gateTick))
                    }

                case .plateOpen(let gateCol, let gateTier):
                    for gi in gates.indices where gates[gi].room == currentRoom && gates[gi].col == gateCol && gates[gi].tier == gateTier {
                        if gates[gi].holdTimer <= 0.2 {
                            events.append(.playSFX(.gateTick))
                        }
                        gates[gi].holdTimer = 9.0
                    }
                    if !exitUnlocked && stage.number < 6 {
                        exitUnlocked = true
                        events.append(.playSFX(.potionChime))
                        events.append(.banner("PALACE EXIT ARCHWAY UNLOCKED!", 0x38E8FF))
                    }

                case .scimitarPedestal:
                    mutableRooms[currentRoom][tier][col] = .solidStone
                    heroHasSword = true
                    _ = PersistenceManager.shared.unlockSeal("first_blade")
                    events.append(.playSFX(.swordDraw))
                    events.append(.banner("GOLDEN SCIMITAR CLAIMED!", 0xF6C445))

                case .potionHeal:
                    mutableRooms[currentRoom][tier][col] = .solidStone
                    heroHP = min(heroMaxHP, heroHP + 2)
                    heroPose = .drinkPotion
                    events.append(.playSFX(.potionChime))
                    events.append(.banner("RUBY ELIXIR • LIFE RESTORED!", 0xE33946))

                case .potionMaxLife:
                    mutableRooms[currentRoom][tier][col] = .solidStone
                    heroMaxHP = min(7, heroMaxHP + 1)
                    heroHP = heroMaxHP
                    heroPose = .drinkPotion
                    _ = PersistenceManager.shared.unlockSeal("life_amphora")
                    events.append(.playSFX(.potionChime))
                    events.append(.banner("GOLDEN AMPHORA • MAX LIFE UP!", 0xF6C445))

                case .potionFeather:
                    mutableRooms[currentRoom][tier][col] = .solidStone
                    featherTimer = 14.0
                    _ = PersistenceManager.shared.unlockSeal("feather_leap")
                    events.append(.playSFX(.mirrorShimmer))
                    events.append(.banner("EMERALD FEATHER-FALL ACTIVE!", 0x2FE388))

                case .magicMirror:
                    mutableRooms[currentRoom][tier][col] = .solidStone
                    _ = PersistenceManager.shared.unlockSeal("mirror_soul")
                    events.append(.playSFX(.mirrorShimmer))
                    events.append(.spark(CGPoint(x: heroX, y: heroY + 44), 0x38E8FF))
                    events.append(.banner("SILVER MIRROR CROSSED • PHANTOM AWAKENED!", 0x38E8FF))

                case .exitArchway:
                    if exitUnlocked {
                        events.append(.playSFX(.potionChime))
                        if stage.number >= 6 {
                            PersistenceManager.shared.recordVictory(secondsUsed: Int(elapsedSeconds))
                            events.append(.campaignWon)
                        } else {
                            events.append(.stageCleared)
                        }
                        return events
                    }

                default:
                    break
                }
            }
        }

        // Update Enemy AI & Sword Duelists
        events.append(contentsOf: updateEnemies(dt: dt))

        // Select Hero Animation Pose
        if hurtTimer > 0.15 {
            heroPose = .hurt
        } else if parryTimer > 0 {
            heroPose = .swordParry
        } else if attackTimer > 0 {
            heroPose = .swordSlash
        } else if !heroGrounded {
            heroPose = .jumpArc
        } else if inSwordCombat {
            heroPose = .swordGuard
        } else if abs(heroVX) > 15 {
            if sneakHeld {
                heroPose = .sneak
            } else {
                runCycle += dt * 10.5
                heroPose = (Int(runCycle) % 2 == 0) ? .runA : .runB
                if stepSFXCooldown <= 0 {
                    stepSFXCooldown = 0.24
                    events.append(.playSFX(.footstep))
                }
            }
        } else {
            heroPose = sneakHeld ? .sneak : .idle
        }

        return events
    }

    private func updateEnemies(dt: CGFloat) -> [DungeonEvent] {
        var events: [DungeonEvent] = []
        let heroTier = nearestTier(forY: heroY)

        for i in enemies.indices where enemies[i].room == currentRoom && !enemies[i].defeated {
            if enemies[i].downTimer > 0 {
                enemies[i].downTimer -= dt
                if enemies[i].downTimer <= 0 {
                    enemies[i].hp = 2
                    enemies[i].pose = .swordGuard
                    events.append(.banner("THE IMMORTAL SKELETON RISES!", 0xD8DFEA))
                }
                continue
            }

            if enemies[i].staggerTimer > 0 {
                enemies[i].staggerTimer -= dt
                enemies[i].pose = .hurt
                continue
            }

            if enemies[i].actionTimer > 0 {
                enemies[i].actionTimer -= dt
                if enemies[i].actionTimer <= 0 {
                    enemies[i].pose = .swordGuard
                }
                continue
            }

            guard enemies[i].tier == heroTier else { continue }
            let dx = heroX - enemies[i].x
            enemies[i].facing = (dx >= 0) ? 1 : -1
            let dist = abs(dx)

            // Stage 5 Mirror Phantom peaceful union!
            if enemies[i].archetype == .shadowPhantom && !isDuelArenaMode && dist < 56 && attackTimer <= 0 {
                enemies[i].defeated = true
                exitUnlocked = true
                heroHP = heroMaxHP
                events.append(.playSFX(.mirrorShimmer))
                events.append(.spark(CGPoint(x: heroX, y: heroY + 46), 0x38E8FF))
                events.append(.banner("SHADOW REUNITED • EXIT BRIDGE LIT!", 0x38E8FF))
                continue
            }

            // Advance to fencing distance (~74pt)
            if dist > 80 && dist < 340 {
                let nextX = enemies[i].x + enemies[i].facing * 105.0 * dt
                let nextCol = Self.colIndex(forX: nextX)
                if hasFloorSupport(room: currentRoom, tier: enemies[i].tier, col: nextCol) &&
                    tileAt(room: currentRoom, tier: enemies[i].tier, col: nextCol) != .spikes {
                    enemies[i].x = nextX
                }
                enemies[i].pose = .swordGuard
            } else if dist <= 88 {
                enemies[i].aiTimer -= dt
                if enemies[i].aiTimer <= 0 {
                    enemies[i].aiTimer = (enemies[i].archetype == .grandVizier) ? 0.68 : 0.92
                    enemies[i].actionTimer = 0.26
                    enemies[i].pose = .swordSlash
                    events.append(.playSFX(.swordSlash))

                    if parryTimer > 0 {
                        // Hero parried!
                        riposteWindow = 0.65
                        enemies[i].staggerTimer = 0.55
                        events.append(.playSFX(.swordParry))
                        events.append(.spark(CGPoint(x: (heroX + enemies[i].x) * 0.5, y: heroY + 48), 0x38E8FF))
                    } else if hurtTimer <= 0 && heroGrounded {
                        events.append(.playSFX(.swordHit))
                        events.append(.spark(CGPoint(x: heroX, y: heroY + 44), 0xFF4444))
                        events.append(contentsOf: damageHero(amount: 1, reason: "DEFEATED BY \(enemies[i].archetype.rawValue)!"))
                    }
                }
            }
        }
        return events
    }

    private func checkEnemyAfterHit(index i: Int) -> [DungeonEvent] {
        var events: [DungeonEvent] = []
        let eCol = Self.colIndex(forX: enemies[i].x)
        let overHazard = !hasFloorSupport(room: currentRoom, tier: enemies[i].tier, col: eCol) ||
            tileAt(room: currentRoom, tier: enemies[i].tier, col: eCol) == .spikes

        if overHazard {
            enemies[i].defeated = true
            PersistenceManager.shared.recordDefeat()
            if enemies[i].archetype == .skeletonKnight {
                _ = PersistenceManager.shared.unlockSeal("bone_breaker")
            }
            events.append(.playSFX(.spikeSpring))
            events.append(.banner("\(enemies[i].archetype.rawValue) CAST INTO TRAP!", 0xFFD966))
        } else if enemies[i].hp <= 0 {
            if enemies[i].archetype == .skeletonKnight && !isDuelArenaMode {
                enemies[i].downTimer = 3.2
                enemies[i].pose = .hurt
                events.append(.banner("BONES SCATTERED • SPRINT PAST OR SHOVE OFF!", 0xD8DFEA))
            } else {
                enemies[i].defeated = true
                PersistenceManager.shared.recordDefeat()
                events.append(.banner("\(enemies[i].archetype.rawValue) VANQUISHED!", 0xFFD966))
            }
        }

        if enemies[i].defeated {
            if isDuelArenaMode {
                duelStreak += 1
                PersistenceManager.shared.recordDuelStreak(duelStreak)
                events.append(.stageCleared)
            } else if enemies[i].archetype == .grandVizier {
                exitUnlocked = true
                events.append(.playSFX(.potionChime))
                events.append(.banner("VIZIER ZAFAR FALLS! STEP INTO THE HOURGLASS ARCH!", 0x38E8FF))
            }
        }
        return events
    }

    private func damageHero(amount: Int, reason: String) -> [DungeonEvent] {
        heroHP = max(0, heroHP - amount)
        hurtTimer = 0.45
        HapticsManager.heavyImpact()
        if heroHP <= 0 {
            return [.shake(9.0), .heroDied(reason)]
        }
        return [.shake(5.0)]
    }

    func nearestTier(forY y: CGFloat) -> Int {
        var best = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        for t in 0...2 {
            let d = abs(Self.tierHeights[t] - y)
            if d < bestDist {
                bestDist = d
                best = t
            }
        }
        return best
    }
}
