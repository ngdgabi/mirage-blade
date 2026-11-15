import Foundation
import SpriteKit
import GameController

@MainActor
final class GameScene: SKScene {
    private(set) var mode: SceneMode = .titleMenu
    private var engine = DungeonEngine(stageIndex: 0)

    private let worldLayer = SKNode()
    private let bgLayer = SKNode()
    private let tileLayer = SKNode()
    private let actorLayer = SKNode()
    private let fxLayer = SKNode()
    private let hudLayer = SKNode()
    private let menuLayer = SKNode()
    private let crtOverlay = SKSpriteNode()

    private var lastUpdateTime: TimeInterval = 0
    private var animClock: CGFloat = 0
    private var shakeIntensity: CGFloat = 0
    private var isPausedOverlay: Bool = false

    // Keyboard state
    private var heldKeys: Set<UInt16> = []
    private var justPressedStrike: Bool = false
    private var justPressedJump: Bool = false

    // Menu state
    private var selectedMenuIndex: Int = 0
    private var menuButtons: [(rect: CGRect, label: String, action: () -> Void)] = []
    private var bannerNode: SKNode?
    private var hourglassEasterCount: Int = 0

    var isActionArcadePhase: Bool {
        (mode == .dungeonPlay || mode == .duelArena) && !isPausedOverlay
    }

    override func didMove(to view: SKView) {
        backgroundColor = Palette.hdNightSky
        removeAllChildren()

        addChild(worldLayer)
        worldLayer.addChild(bgLayer)
        worldLayer.addChild(tileLayer)
        worldLayer.addChild(actorLayer)
        worldLayer.addChild(fxLayer)
        addChild(hudLayer)
        addChild(menuLayer)

        crtOverlay.texture = SpriteFactory.shared.scanlineOverlayTexture()
        crtOverlay.size = CGSize(width: 1280, height: 800)
        crtOverlay.position = CGPoint(x: 640, y: 400)
        crtOverlay.zPosition = 900
        addChild(crtOverlay)

        let s = PersistenceManager.shared.data.settings
        AudioSynth.shared.setChipMode(s.audioChip)
        AudioSynth.shared.setVolume(s.masterVolume)
        refreshCRTOverlay()
        enterTitleMenu()
    }

    private func refreshCRTOverlay() {
        let theme = PersistenceManager.shared.data.settings.visualTheme
        crtOverlay.isHidden = (theme == .hdOverdrive)
        crtOverlay.alpha = (theme == .crtCabinet) ? 0.55 : 0.32
    }

    // MARK: - Public Scene Navigation

    func enterTitleMenu() {
        mode = .titleMenu
        isPausedOverlay = false
        selectedMenuIndex = 0
        AudioSynth.shared.setTrack(.palaceOverture)
        renderStaticMenuScreen()
    }

    func startNewEscape(fromStage stageIdx: Int = 0) {
        mode = .dungeonPlay
        isPausedOverlay = false
        engine = DungeonEngine(stageIndex: stageIdx, carryMaxHP: 3)
        engine.remainingSeconds = 3600.0
        engine.elapsedSeconds = 0
        selectMusicForStage(engine.stage)
        menuLayer.removeAllChildren()
        renderPlayfieldFrame()
    }

    func startQuickDuelArena(bout: Int = 1) {
        mode = .duelArena
        isPausedOverlay = false
        if bout == 1 {
            engine = DungeonEngine(stageIndex: 2, carryMaxHP: 4)
            engine.duelStreak = 0
        }
        engine.setupQuickDuelBout(bout: bout)
        AudioSynth.shared.setTrack(.scimitarDuel)
        menuLayer.removeAllChildren()
        renderPlayfieldFrame()
        showFloatingBanner("BOUT \(bout): \(engine.enemies.first?.archetype.rawValue ?? "SENTINEL")", hex: 0xF6C445)
    }

    func togglePauseFromUI() {
        guard mode == .dungeonPlay || mode == .duelArena else { return }
        isPausedOverlay.toggle()
        HapticsManager.tap()
        renderPlayfieldFrame()
    }

    func cycleVisualTheme() {
        PersistenceManager.shared.updateSettings { $0.visualTheme = $0.visualTheme.next }
        let theme = PersistenceManager.shared.data.settings.visualTheme
        if theme == .retro1989 && PersistenceManager.shared.data.settings.audioChip == .retroAdLib {
            _ = PersistenceManager.shared.unlockSeal("era_traveler")
        }
        refreshCRTOverlay()
        AudioSynth.shared.playSFX(.menuSelect)
        if mode == .dungeonPlay || mode == .duelArena {
            showFloatingBanner("VISUALS: \(theme.rawValue)", hex: 0x38E8FF)
            renderPlayfieldFrame()
        } else {
            renderStaticMenuScreen()
        }
    }

    func cycleAudioChip() {
        PersistenceManager.shared.updateSettings { $0.audioChip = $0.audioChip.next }
        let chip = PersistenceManager.shared.data.settings.audioChip
        AudioSynth.shared.setChipMode(chip)
        if PersistenceManager.shared.data.settings.visualTheme == .retro1989 && chip == .retroAdLib {
            _ = PersistenceManager.shared.unlockSeal("era_traveler")
        }
        AudioSynth.shared.playSFX(.menuSelect)
        if mode == .dungeonPlay || mode == .duelArena {
            showFloatingBanner("AUDIO: \(chip.rawValue)", hex: 0xF6C445)
            renderPlayfieldFrame()
        } else {
            renderStaticMenuScreen()
        }
    }

    private func selectMusicForStage(_ st: StageBlueprint) {
        switch st.biome {
        case .sunkenDungeon, .undeadCatacombs: AudioSynth.shared.setTrack(.dungeonAmbient)
        case .moonlitCourtyard:                AudioSynth.shared.setTrack(.scimitarDuel)
        case .mirrorHall, .astralBridge:       AudioSynth.shared.setTrack(.mirrorMystique)
        case .vizierSanctum:                   AudioSynth.shared.setTrack(.vizierShowdown)
        }
    }

    // MARK: - 120Hz Update Loop

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat
        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = CGFloat(min(1.0 / 20.0, max(1.0 / 240.0, currentTime - lastUpdateTime)))
        }
        lastUpdateTime = currentTime
        animClock += dt

        guard mode == .dungeonPlay || mode == .duelArena else { return }
        guard !isPausedOverlay else { return }

        let input = gatherInput()
        let relaxed = PersistenceManager.shared.data.settings.relaxedHourglass
        let evs = engine.step(
            dt: dt,
            moveX: input.mx,
            moveY: input.my,
            sneakHeld: input.sneak,
            strikePressed: input.strike,
            jumpOrParryPressed: input.jump,
            relaxedTimer: relaxed
        )
        processEvents(evs)

        if shakeIntensity > 0 {
            worldLayer.position = CGPoint(
                x: CGFloat.random(in: -shakeIntensity...shakeIntensity),
                y: CGFloat.random(in: -shakeIntensity...shakeIntensity)
            )
            shakeIntensity = max(0, shakeIntensity - dt * 28.0)
        } else {
            worldLayer.position = .zero
        }

        if mode == .dungeonPlay || mode == .duelArena {
            renderPlayfieldFrame()
        }
    }

    private func gatherInput() -> (mx: CGFloat, my: CGFloat, sneak: Bool, strike: Bool, jump: Bool) {
        var mx: CGFloat = 0
        var my: CGFloat = 0
        var sneak = false
        var strike = justPressedStrike
        var jump = justPressedJump
        justPressedStrike = false
        justPressedJump = false

        // Keyboard (Mac)
        if heldKeys.contains(123) || heldKeys.contains(0)  { mx -= 1 } // Left / A
        if heldKeys.contains(124) || heldKeys.contains(2)  { mx += 1 } // Right / D
        if heldKeys.contains(126) || heldKeys.contains(13) { my += 1 } // Up / W
        if heldKeys.contains(125) || heldKeys.contains(1)  { my -= 1 } // Down / S
        if heldKeys.contains(56) || heldKeys.contains(60) || heldKeys.contains(6) { sneak = true } // Shift / Z

        // Touch Controls (iOS / iPadOS)
        let t = TouchInputState.shared
        if abs(t.moveDX) > 0.12 { mx = t.moveDX }
        if abs(t.moveDY) > 0.18 { my = t.moveDY }
        if t.primaryHeld { sneak = true }
        if t.primaryJustPressed { strike = true; t.primaryJustPressed = false }
        if t.secondaryJustPressed { jump = true; t.secondaryJustPressed = false }

        // Bluetooth Gamepad (PS5 DualSense / Xbox / MFi)
        if let pad = GCController.controllers().first?.extendedGamepad {
            let gx = CGFloat(pad.leftThumbstick.xAxis.value)
            let gy = CGFloat(pad.leftThumbstick.yAxis.value)
            if abs(gx) > 0.15 { mx = gx }
            if abs(gy) > 0.20 { my = gy }
            if pad.dpad.left.isPressed  { mx = -1 }
            if pad.dpad.right.isPressed { mx = 1 }
            if pad.dpad.up.isPressed    { my = 1 }
            if pad.dpad.down.isPressed  { my = -1 }
            if pad.leftTrigger.isPressed || pad.leftShoulder.isPressed { sneak = true }
            if pad.buttonX.isPressed { strike = true }
            if pad.buttonA.isPressed { jump = true }
        }

        return (max(-1, min(1, mx)), max(-1, min(1, my)), sneak, strike, jump)
    }

    private func processEvents(_ evs: [DungeonEvent]) {
        for ev in evs {
            switch ev {
            case .playSFX(let s):
                AudioSynth.shared.playSFX(s)
            case .banner(let txt, let hex):
                showFloatingBanner(txt, hex: hex)
            case .spark(let pt, let hex):
                spawnSparkBurst(at: pt, hex: hex)
            case .shake(let amt):
                shakeIntensity = max(shakeIntensity, amt)
            case .stageCleared:
                if mode == .duelArena {
                    startQuickDuelArena(bout: engine.duelBoutNumber + 1)
                } else {
                    mode = .stageClear
                    AudioSynth.shared.setTrack(.victoryFanfare)
                    renderStaticMenuScreen()
                }
            case .campaignWon:
                mode = .victoryEnding
                AudioSynth.shared.setTrack(.victoryFanfare)
                renderStaticMenuScreen()
            case .heroDied(let reason):
                mode = .gameOver
                renderStaticMenuScreen(deathReason: reason)
            }
        }
    }

    private func showFloatingBanner(_ text: String, hex: UInt32) {
        bannerNode?.removeFromParent()
        let wrap = SKNode()
        wrap.position = CGPoint(x: 640, y: 586)
        wrap.zPosition = 500
        let bg = SKShapeNode(rectOf: CGSize(width: 620, height: 34), cornerRadius: 8)
        bg.fillColor = SKColor.rgba(0.05, 0.08, 0.18, 0.88)
        bg.strokeColor = SKColor.hex(hex)
        bg.lineWidth = 2.0
        wrap.addChild(bg)

        let lbl = CoreTextLabelRenderer.makeLabelNode(text, fontSize: 15, color: SKColor.hex(hex))
        wrap.addChild(lbl)
        hudLayer.addChild(wrap)
        bannerNode = wrap

        wrap.run(.sequence([
            .wait(forDuration: 1.9),
            .fadeOut(withDuration: 0.35),
            .removeFromParent()
        ]))
    }

    private func spawnSparkBurst(at pt: CGPoint, hex: UInt32) {
        for i in 0..<10 {
            let ang = CGFloat(i) * (.pi * 2.0 / 10.0)
            let dot = SKShapeNode(circleOfRadius: 4.0)
            dot.fillColor = SKColor.hex(hex)
            dot.strokeColor = .white
            dot.lineWidth = 1.0
            dot.position = pt
            dot.zPosition = 220
            fxLayer.addChild(dot)
            let dx = cos(ang) * 46.0
            let dy = sin(ang) * 46.0
            dot.run(.sequence([
                .group([.moveBy(x: dx, y: dy, duration: 0.24), .fadeOut(withDuration: 0.24)]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Playfield & Palace Architecture Renderer

    private func renderPlayfieldFrame() {
        bgLayer.removeAllChildren()
        tileLayer.removeAllChildren()
        actorLayer.removeAllChildren()
        // Keep active transient nodes in hudLayer (bannerNode), rebuild static HUD nodes
        for child in hudLayer.children where child !== bannerNode {
            child.removeFromParent()
        }

        let theme = PersistenceManager.shared.data.settings.visualTheme
        let retro = (theme == .retro1989)
        let biome = engine.stage.biome

        // 1. Full-bleed Arabian Night / Limestone Dungeon Backdrop (covers full 1280x800)
        drawPalaceBackdrop(biome: biome, retro: retro)

        // 2. Room Torches
        let roomDef = engine.stage.rooms[engine.currentRoom]
        let flameFrame = Int(animClock * 7.5) % 2
        for t in roomDef.torches {
            let tx = DungeonEngine.colCenterX(t.col)
            let ty = DungeonEngine.tierY(t.tier) + 56
            let sp = SKSpriteNode(texture: SpriteFactory.shared.torchTexture(frame: flameFrame, retro: retro))
            sp.position = CGPoint(x: tx, y: ty)
            sp.zPosition = 12
            tileLayer.addChild(sp)
        }

        // Grand Vizier's Colossal Glowing Hourglass centerpiece in Stage 6 Room 1!
        if engine.stage.number == 6 && engine.currentRoom == 1 {
            let hg = SKSpriteNode(texture: SpriteFactory.shared.hourglassPropTexture(retro: retro))
            hg.size = CGSize(width: 148, height: 214)
            hg.position = CGPoint(x: 640, y: 295)
            hg.zPosition = 14
            tileLayer.addChild(hg)
        }

        // 3. 3 Tiers x 10 Columns of Stone Blocks, Traps, Gates, Potions & Archway
        for tier in 0..<3 {
            let floorY = DungeonEngine.tierY(tier)
            for col in 0..<10 {
                let cx = DungeonEngine.colCenterX(col)
                let rawFeat = engine.mutableRooms[engine.currentRoom][tier][col]

                // Loose falling tile check
                if rawFeat == .looseSlab {
                    if let lt = engine.looseTiles.first(where: { $0.room == engine.currentRoom && $0.tier == tier && $0.col == col }) {
                        if !lt.gone {
                            let wobble: CGFloat = (lt.timer > 0 && !lt.falling) ? sin(animClock * 55.0) * 4.0 : 0
                            let blk = SKSpriteNode(texture: SpriteFactory.shared.stoneBlockTexture(biome: biome, loose: true, retro: retro))
                            blk.position = CGPoint(x: cx + wobble, y: floorY - 14 + lt.fallenY)
                            blk.zPosition = 25
                            tileLayer.addChild(blk)
                        }
                    }
                    continue
                }

                guard rawFeat != .empty else { continue }

                // Base stone floor block
                let block = SKSpriteNode(texture: SpriteFactory.shared.stoneBlockTexture(biome: biome, loose: false, retro: retro))
                block.position = CGPoint(x: cx, y: floorY - 14)
                block.zPosition = 20
                tileLayer.addChild(block)

                switch rawFeat {
                case .spikes:
                    let heroNearFast = abs(engine.heroX - cx) < 58 && abs(engine.heroY - floorY) < 30 && abs(engine.heroVX) > 130
                    let spk = SKSpriteNode(texture: SpriteFactory.shared.spikesTexture(extended: heroNearFast || !retro, retro: retro))
                    spk.position = CGPoint(x: cx, y: floorY + 20)
                    spk.zPosition = 28
                    tileLayer.addChild(spk)

                case .chopper:
                    let ratio = engine.chopperClosedRatio(col: col)
                    let ch = SKSpriteNode(texture: SpriteFactory.shared.chopperTexture(closedRatio: ratio, retro: retro))
                    ch.position = CGPoint(x: cx, y: floorY + 74)
                    ch.zPosition = 45
                    tileLayer.addChild(ch)

                case .plateOpen:
                    let plate = SKShapeNode(rectOf: CGSize(width: 64, height: 7), cornerRadius: 2)
                    plate.fillColor = Palette.hdGold
                    plate.strokeColor = .black
                    plate.position = CGPoint(x: cx, y: floorY + 3)
                    plate.zPosition = 26
                    tileLayer.addChild(plate)

                case .portcullis:
                    let openRatio = engine.gates.first(where: { $0.room == engine.currentRoom && $0.tier == tier && $0.col == col })?.openRatio ?? 0
                    let gate = SKSpriteNode(texture: SpriteFactory.shared.portcullisTexture(openRatio: openRatio, retro: retro))
                    gate.position = CGPoint(x: cx, y: floorY + 74)
                    gate.zPosition = 44
                    tileLayer.addChild(gate)

                case .exitArchway:
                    drawExitArchway(at: CGPoint(x: cx, y: floorY), unlocked: engine.exitUnlocked, retro: retro)

                case .scimitarPedestal:
                    let ped = SKShapeNode(rectOf: CGSize(width: 44, height: 14), cornerRadius: 3)
                    ped.fillColor = Palette.hdGold
                    ped.position = CGPoint(x: cx, y: floorY + 7)
                    ped.zPosition = 29
                    tileLayer.addChild(ped)

                    let gleam = CoreTextLabelRenderer.makeLabelNode("⚔ SCIMITAR", fontSize: 13, color: Palette.hdGold)
                    gleam.position = CGPoint(x: cx, y: floorY + 32 + sin(animClock * 5) * 4)
                    gleam.zPosition = 30
                    tileLayer.addChild(gleam)

                case .potionHeal, .potionMaxLife, .potionFeather:
                    let pot = SKSpriteNode(texture: SpriteFactory.shared.potionTexture(kind: rawFeat, retro: retro))
                    pot.position = CGPoint(x: cx, y: floorY + 22 + sin(animClock * 4.5) * 3)
                    pot.zPosition = 32
                    tileLayer.addChild(pot)

                case .magicMirror:
                    let mir = SKShapeNode(rectOf: CGSize(width: 24, height: 112), cornerRadius: 10)
                    mir.fillColor = SKColor.rgba(0.25, 0.92, 1.0, 0.58)
                    mir.strokeColor = Palette.hdGold
                    mir.lineWidth = 3.5
                    mir.position = CGPoint(x: cx, y: floorY + 58)
                    mir.zPosition = 36
                    tileLayer.addChild(mir)

                default:
                    break
                }
            }
        }

        // 4. Active Enemies in Current Room
        for e in engine.enemies where e.room == engine.currentRoom && !e.defeated {
            let ey = DungeonEngine.tierY(e.tier)
            let sp = SKSpriteNode(texture: SpriteFactory.shared.fighterTexture(
                isHero: false,
                archetype: e.archetype,
                pose: e.pose,
                hasSword: true,
                retro: retro
            ))
            sp.size = CGSize(width: 80, height: 104)
            sp.xScale = (e.facing >= 0) ? 1.0 : -1.0
            sp.yScale = (e.downTimer > 0) ? 0.32 : 1.0
            sp.position = CGPoint(x: e.x, y: ey + (e.downTimer > 0 ? 14 : 46))
            sp.zPosition = 60
            actorLayer.addChild(sp)
        }

        // 5. Mirage Runner Hero
        let heroSprite = SKSpriteNode(texture: SpriteFactory.shared.fighterTexture(
            isHero: true,
            pose: engine.heroPose,
            hasSword: engine.heroHasSword,
            retro: retro
        ))
        heroSprite.size = CGSize(width: 80, height: 104)
        heroSprite.xScale = (engine.heroFacing >= 0) ? 1.0 : -1.0
        heroSprite.position = CGPoint(x: engine.heroX, y: engine.heroY + 46)
        heroSprite.zPosition = 65
        if engine.featherTimer > 0 {
            let aura = SKShapeNode(circleOfRadius: 42)
            aura.strokeColor = Palette.hdEmerald
            aura.fillColor = SKColor.rgba(0.18, 0.89, 0.53, 0.14)
            aura.lineWidth = 2.0
            aura.position = heroSprite.position
            aura.zPosition = 64
            actorLayer.addChild(aura)
        }
        actorLayer.addChild(heroSprite)

        // 6. Top & Bottom HUD inside Universal Safe Box (x: 165..1115, y: 142..652)
        drawDungeonHUD(retro: retro)

        if isPausedOverlay {
            drawPauseModal()
        }
    }

    private func drawPalaceBackdrop(biome: PalaceBiome, retro: Bool) {
        let bgFill: SKColor = {
            if retro { return Palette.egaBlack }
            switch biome {
            case .sunkenDungeon:    return SKColor.hex(0x0B0F1E)
            case .undeadCatacombs:  return SKColor.hex(0x110B1C)
            case .moonlitCourtyard: return SKColor.hex(0x09132E)
            case .mirrorHall:       return SKColor.hex(0x0A1B30)
            case .astralBridge:     return SKColor.hex(0x071E2E)
            case .vizierSanctum:    return SKColor.hex(0x1A0926)
            }
        }()
        let rect = SKShapeNode(rectOf: CGSize(width: 1280, height: 800))
        rect.fillColor = bgFill
        rect.strokeColor = .clear
        rect.position = CGPoint(x: 640, y: 400)
        rect.zPosition = 1
        bgLayer.addChild(rect)

        // Starfield & Crescent Moon for Courtyard / Spire / Sanctum
        if !retro && (biome == .moonlitCourtyard || biome == .astralBridge || biome == .vizierSanctum) {
            for s in 0..<28 {
                let sx = CGFloat((s * 137 + 90) % 1180) + 50
                let sy = CGFloat((s * 89 + 260) % 440) + 260
                let star = SKShapeNode(circleOfRadius: (s % 3 == 0) ? 2.3 : 1.4)
                star.fillColor = SKColor.rgba(1, 0.96, 0.82, 0.75)
                star.strokeColor = .clear
                star.position = CGPoint(x: sx, y: sy)
                star.zPosition = 2
                bgLayer.addChild(star)
            }
            let moon = SKShapeNode(circleOfRadius: 34)
            moon.fillColor = SKColor.hex(0xFFF3C4)
            moon.strokeColor = .clear
            moon.position = CGPoint(x: 980, y: 560)
            moon.zPosition = 2
            bgLayer.addChild(moon)
        }

        // Ornate Arabian Pointed Palace Arches across playfield
        let archStroke = retro ? Palette.egaDarkGray : SKColor.rgba(0.96, 0.77, 0.27, 0.22)
        for i in 0..<4 {
            let ax = 260.0 + CGFloat(i) * 252.0
            let arch = SKShapeNode(rectOf: CGSize(width: 196, height: 440), cornerRadius: 88)
            arch.fillColor = retro ? .clear : SKColor.rgba(0.08, 0.12, 0.25, 0.42)
            arch.strokeColor = archStroke
            arch.lineWidth = 2.5
            arch.position = CGPoint(x: ax, y: 390)
            arch.zPosition = 4
            bgLayer.addChild(arch)
        }
    }

    private func drawExitArchway(at pt: CGPoint, unlocked: Bool, retro: Bool) {
        let door = SKShapeNode(rectOf: CGSize(width: 68, height: 118), cornerRadius: 30)
        door.fillColor = unlocked ? SKColor.rgba(0.22, 0.91, 1.0, 0.38) : SKColor.hex(0x1A2034)
        door.strokeColor = unlocked ? Palette.hdCyanMagic : Palette.hdGold
        door.lineWidth = 3.5
        door.position = CGPoint(x: pt.x, y: pt.y + 59)
        door.zPosition = 24
        tileLayer.addChild(door)

        let tag = CoreTextLabelRenderer.makeLabelNode(unlocked ? "EXIT OPEN" : "SEALED", fontSize: 11, color: unlocked ? Palette.hdCyanMagic : Palette.hdGold)
        tag.position = CGPoint(x: pt.x, y: pt.y + 128)
        tag.zPosition = 30
        tileLayer.addChild(tag)
    }

    private func drawDungeonHUD(retro: Bool) {
        // Top HUD Bar (y = 638, safely inside Universal Safe Box y <= 665!)
        let topBar = SKShapeNode(rectOf: CGSize(width: 930, height: 38), cornerRadius: 10)
        topBar.fillColor = retro ? Palette.egaBlack : SKColor.rgba(0.05, 0.08, 0.18, 0.88)
        topBar.strokeColor = Palette.hdGold
        topBar.lineWidth = 2.0
        topBar.position = CGPoint(x: 640, y: 638)
        topBar.zPosition = 400
        hudLayer.addChild(topBar)

        let roomTitle = mode == .duelArena
            ? "DUEL ARENA • STREAK \(engine.duelStreak)"
            : "STAGE \(engine.stage.number)/6 • \(engine.stage.rooms[engine.currentRoom].title)"
        let leftLbl = CoreTextLabelRenderer.makeLabelNode(roomTitle, fontSize: 14, color: .white)
        leftLbl.horizontalAlignmentMode = .left
        leftLbl.position = CGPoint(x: 192, y: 638)
        leftLbl.zPosition = 401
        hudLayer.addChild(leftLbl)

        let mins = Int(engine.remainingSeconds) / 60
        let secs = Int(engine.remainingSeconds) % 60
        let relaxed = PersistenceManager.shared.data.settings.relaxedHourglass
        let timeStr = mode == .duelArena
            ? "BOUT #\(engine.duelBoutNumber)"
            : (relaxed ? "⏳ RELAXED SANDS" : String(format: "⏳ %02d:%02d LEFT", mins, secs))
        let rightLbl = CoreTextLabelRenderer.makeLabelNode(timeStr, fontSize: 15, color: Palette.hdGold)
        rightLbl.horizontalAlignmentMode = .right
        rightLbl.position = CGPoint(x: 1088, y: 638)
        rightLbl.zPosition = 401
        hudLayer.addChild(rightLbl)

        // Bottom Classic 1989 Triangular Ruby/Cyan Life-Pip Bar (y = 148, safely inside y >= 135!)
        let botBar = SKShapeNode(rectOf: CGSize(width: 720, height: 30), cornerRadius: 8)
        botBar.fillColor = retro ? Palette.egaBlack : SKColor.rgba(0.05, 0.08, 0.18, 0.88)
        botBar.strokeColor = SKColor.rgba(0.96, 0.77, 0.27, 0.55)
        botBar.lineWidth = 1.5
        botBar.position = CGPoint(x: 640, y: 148)
        botBar.zPosition = 400
        hudLayer.addChild(botBar)

        // Hero Ruby Triangles (Left)
        let heroTag = CoreTextLabelRenderer.makeLabelNode("RUNNER", fontSize: 12, color: Palette.hdGold)
        heroTag.horizontalAlignmentMode = .left
        heroTag.position = CGPoint(x: 296, y: 148)
        heroTag.zPosition = 401
        hudLayer.addChild(heroTag)

        for i in 0..<engine.heroMaxHP {
            let filled = i < engine.heroHP
            let tri = makeLifeTriangle(filled: filled, color: Palette.hdCrimson)
            tri.position = CGPoint(x: 372 + CGFloat(i) * 24, y: 148)
            tri.zPosition = 402
            hudLayer.addChild(tri)
        }

        // Enemy Cyan/Purple Triangles (Right, when guard is present!)
        if let foe = engine.activeEnemyInCurrentRoom() {
            let foeTag = CoreTextLabelRenderer.makeLabelNode(foe.archetype == .grandVizier ? "VIZIER" : "GUARD", fontSize: 12, color: Palette.hdCyanMagic)
            foeTag.horizontalAlignmentMode = .right
            foeTag.position = CGPoint(x: 984, y: 148)
            foeTag.zPosition = 401
            hudLayer.addChild(foeTag)

            for i in 0..<foe.maxHP {
                let filled = i < foe.hp
                let tri = makeLifeTriangle(filled: filled, color: Palette.hdCyanMagic)
                tri.position = CGPoint(x: 904 - CGFloat(i) * 24, y: 148)
                tri.zPosition = 402
                hudLayer.addChild(tri)
            }
        } else {
            let hint = CoreTextLabelRenderer.makeLabelNode(
                engine.riposteWindow > 0 ? "RIPOSTE READY!" : "[SHIFT/ACT] SNEAK/SLASH  •  [UP/JUMP] LEAP/PARRY",
                fontSize: 11,
                color: SKColor.hex(0xB8C7E8)
            )
            hint.horizontalAlignmentMode = .right
            hint.position = CGPoint(x: 984, y: 148)
            hint.zPosition = 401
            hudLayer.addChild(hint)
        }
    }

    private func makeLifeTriangle(filled: Bool, color: SKColor) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -8, y: -7))
        path.addLine(to: CGPoint(x: 8, y: -7))
        path.addLine(to: CGPoint(x: 0, y: 8))
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.fillColor = filled ? color : SKColor.rgba(0.2, 0.24, 0.34, 0.65)
        node.strokeColor = .white
        node.lineWidth = 1.2
        return node
    }

    private func drawPauseModal() {
        let card = SKShapeNode(rectOf: CGSize(width: 460, height: 220), cornerRadius: 16)
        card.fillColor = SKColor.rgba(0.05, 0.08, 0.18, 0.95)
        card.strokeColor = Palette.hdGold
        card.lineWidth = 3.0
        card.position = CGPoint(x: 640, y: 400)
        card.zPosition = 700
        hudLayer.addChild(card)

        let t1 = CoreTextLabelRenderer.makeLabelNode("HOURGLASS PAUSED", fontSize: 24, color: Palette.hdGold)
        t1.position = CGPoint(x: 640, y: 452)
        t1.zPosition = 701
        hudLayer.addChild(t1)

        let t2 = CoreTextLabelRenderer.makeLabelNode("Tap PAUSE or press P / ESC to Resume", fontSize: 14, color: .white)
        t2.position = CGPoint(x: 640, y: 404)
        t2.zPosition = 701
        hudLayer.addChild(t2)

        let t3 = CoreTextLabelRenderer.makeLabelNode("Press M or click below to Return to Palace Menu", fontSize: 13, color: Palette.hdCyanMagic)
        t3.position = CGPoint(x: 640, y: 350)
        t3.zPosition = 701
        hudLayer.addChild(t3)
    }

    // MARK: - Title Menu, Stage Select, Medals, How-To-Play & Ending Screens

    private func renderStaticMenuScreen(deathReason: String = "") {
        bgLayer.removeAllChildren()
        tileLayer.removeAllChildren()
        actorLayer.removeAllChildren()
        fxLayer.removeAllChildren()
        hudLayer.removeAllChildren()
        menuLayer.removeAllChildren()
        menuButtons.removeAll()

        let retro = (PersistenceManager.shared.data.settings.visualTheme == .retro1989)
        drawPalaceBackdrop(biome: .moonlitCourtyard, retro: retro)

        switch mode {
        case .titleMenu:
            let title = CoreTextLabelRenderer.makeLabelNode("MIRAGE BLADE", fontSize: 44, color: Palette.hdGold)
            title.position = CGPoint(x: 505, y: 616)
            menuLayer.addChild(title)

            let sub = CoreTextLabelRenderer.makeLabelNode("H O U R G L A S S   O F   F A T E", fontSize: 16, color: Palette.hdCyanMagic)
            sub.position = CGPoint(x: 505, y: 576)
            menuLayer.addChild(sub)

            // Interactive Palace Showcase Card on Right (x: 945, y: 400)
            let card = SKShapeNode(rectOf: CGSize(width: 280, height: 340), cornerRadius: 18)
            card.fillColor = SKColor.rgba(0.07, 0.11, 0.24, 0.88)
            card.strokeColor = Palette.hdGold
            card.lineWidth = 2.5
            card.position = CGPoint(x: 945, y: 392)
            menuLayer.addChild(card)

            let hg = SKSpriteNode(texture: SpriteFactory.shared.hourglassPropTexture(retro: retro))
            hg.size = CGSize(width: 132, height: 192)
            hg.position = CGPoint(x: 945, y: 432)
            menuLayer.addChild(hg)

            let heroPreview = SKSpriteNode(texture: SpriteFactory.shared.fighterTexture(isHero: true, pose: .swordGuard, hasSword: true, retro: retro))
            heroPreview.size = CGSize(width: 76, height: 98)
            heroPreview.position = CGPoint(x: 885, y: 302)
            menuLayer.addChild(heroPreview)

            let guardPreview = SKSpriteNode(texture: SpriteFactory.shared.fighterTexture(isHero: false, archetype: .grandVizier, pose: .swordSlash, hasSword: true, retro: retro))
            guardPreview.size = CGSize(width: 76, height: 98)
            guardPreview.xScale = -1
            guardPreview.position = CGPoint(x: 1005, y: 302)
            menuLayer.addChild(guardPreview)

            let gagHint = CoreTextLabelRenderer.makeLabelNode("TAP HOURGLASS FOR SAND MAGIC", fontSize: 11, color: Palette.hdGold)
            gagHint.position = CGPoint(x: 945, y: 242)
            menuLayer.addChild(gagHint)

            let items: [(String, () -> Void)] = [
                ("START PALACE ESCAPE (60:00)", { [weak self] in self?.startNewEscape(fromStage: 0) }),
                ("SELECT PALACE STAGE (1–6)",   { [weak self] in self?.mode = .stageSelect; self?.selectedMenuIndex = 0; self?.renderStaticMenuScreen() }),
                ("QUICK SCIMITAR DUEL ARENA",   { [weak self] in self?.startQuickDuelArena(bout: 1) }),
                ("VIZIER HOURGLASS SHOWDOWN",   { [weak self] in self?.startNewEscape(fromStage: 5) }),
                ("ROYAL TREASURY (12 SEALS)",   { [weak self] in self?.mode = .medalsScreen; self?.renderStaticMenuScreen() }),
                ("HOW TO PLAY & CONTROLS",      { [weak self] in self?.mode = .howToPlay; self?.renderStaticMenuScreen() }),
                ("ERA & AUDIO SETTINGS",        { [weak self] in self?.mode = .settingsScreen; self?.selectedMenuIndex = 0; self?.renderStaticMenuScreen() })
            ]
            buildMenuColumn(items: items, centerX: 465, startY: 510, spacing: 52, width: 520)

            let footer = CoreTextLabelRenderer.makeLabelNode(
                "\(PersistenceManager.shared.data.settings.visualTheme.rawValue) • \(PersistenceManager.shared.data.settings.audioChip.rawValue) • [V/B] LIVE 1989 TOGGLE",
                fontSize: 12,
                color: SKColor.hex(0x9FB4DC)
            )
            footer.position = CGPoint(x: 640, y: 152)
            menuLayer.addChild(footer)

        case .stageSelect:
            addHeader("SELECT PALACE STAGE", subtitle: "Practice Any Chapter or Speedrun the Full Escape")
            var items: [(String, () -> Void)] = PalaceStageCatalog.stages.enumerated().map { idx, st in
                ("STAGE \(st.number): \(st.name)", { [weak self] in self?.startNewEscape(fromStage: idx) })
            }
            items.append(("← BACK TO PALACE MENU", { [weak self] in self?.enterTitleMenu() }))
            buildMenuColumn(items: items, centerX: 640, startY: 505, spacing: 48, width: 620)

        case .medalsScreen:
            let unlocked = PersistenceManager.shared.data.unlockedSeals
            addHeader("ROYAL TREASURY • \(unlocked.count)/12 SEALS", subtitle: "Best Duel Streak: \(PersistenceManager.shared.data.highestDuelStreak) • Guards Defeated: \(PersistenceManager.shared.data.totalGuardsDefeated)")
            for (i, seal) in RoyalSealCatalog.all.enumerated() {
                let col = i % 2
                let row = i / 2
                let x: CGFloat = col == 0 ? 410 : 870
                let y: CGFloat = 505 - CGFloat(row) * 52
                let won = unlocked.contains(seal.id)
                let box = SKShapeNode(rectOf: CGSize(width: 430, height: 44), cornerRadius: 8)
                box.fillColor = won ? SKColor.rgba(0.22, 0.16, 0.04, 0.9) : SKColor.rgba(0.06, 0.09, 0.18, 0.85)
                box.strokeColor = won ? Palette.hdGold : SKColor.hex(0x3B4A6B)
                box.position = CGPoint(x: x, y: y)
                menuLayer.addChild(box)

                let t = CoreTextLabelRenderer.makeLabelNode("\(won ? "★" : "☆") \(seal.title)", fontSize: 13, color: won ? Palette.hdGold : .white)
                t.position = CGPoint(x: x, y: y + 8)
                menuLayer.addChild(t)
                let s = CoreTextLabelRenderer.makeLabelNode(seal.subtitle, fontSize: 10, color: SKColor.hex(0xA8B8D8))
                s.position = CGPoint(x: x, y: y - 9)
                menuLayer.addChild(s)
            }
            buildMenuColumn(items: [("← BACK TO PALACE MENU", { [weak self] in self?.enterTitleMenu() })], centerX: 640, startY: 175, spacing: 48, width: 420)

        case .howToPlay:
            addHeader("ACROBATICS & SCIMITAR FENCING", subtitle: "Inspired by 1989 Cinematic Dungeon Classics")
            let lines = [
                "• RUN & CHASM LEAP: Left/Right (WASD/Stick) + Up/Jump to leap pits & grab high stone ledges!",
                "• CAREFUL SNEAK: Hold Shift / Z / ACT button to tiptoe safely over spikes & stop at pit edges.",
                "• SCIMITAR DUELING: Press Space / ACT to Slash; press Up / JUMP right as a guard swings to PARRY!",
                "• STEEL RIPOSTE: A timed Parry sparks gold and staggers your foe for a double-damage counter-hit!",
                "• PUZZLES & POTIONS: Step on Golden Plates to open Portcullis Gates; Ruby heals, Gold boosts Max Life!",
                "• LIVE 1989 TIME-MACHINE: Press V & B (or tap ERA & CHIP) anytime for 1989 EGA Pixel & AdLib FM!"
            ]
            for (idx, line) in lines.enumerated() {
                let l = CoreTextLabelRenderer.makeLabelNode(line, fontSize: 14, color: idx % 2 == 0 ? .white : Palette.hdCyanMagic)
                l.position = CGPoint(x: 640, y: 500 - CGFloat(idx) * 46)
                menuLayer.addChild(l)
            }
            buildMenuColumn(items: [("← BACK TO PALACE MENU", { [weak self] in self?.enterTitleMenu() })], centerX: 640, startY: 185, spacing: 48, width: 420)

        case .settingsScreen:
            let s = PersistenceManager.shared.data.settings
            addHeader("ERA & PALACE SETTINGS", subtitle: "Customize 120Hz HD vs 1989 EGA & Hourglass Pace")
            let items: [(String, () -> Void)] = [
                ("VISUAL ERA: \(s.visualTheme.rawValue)", { [weak self] in self?.cycleVisualTheme() }),
                ("AUDIO SYNTH: \(s.audioChip.rawValue)",  { [weak self] in self?.cycleAudioChip() }),
                ("HOURGLASS TIMER: \(s.relaxedHourglass ? "RELAXED (INFINITE)" : "CLASSIC 60 MINUTES")", { [weak self] in
                    PersistenceManager.shared.updateSettings { $0.relaxedHourglass.toggle() }
                    AudioSynth.shared.playSFX(.menuSelect)
                    self?.renderStaticMenuScreen()
                }),
                ("← BACK TO PALACE MENU", { [weak self] in self?.enterTitleMenu() })
            ]
            buildMenuColumn(items: items, centerX: 640, startY: 470, spacing: 58, width: 580)

        case .stageClear:
            let nextStage = min(5, engine.stage.number)
            addHeader("STAGE \(engine.stage.number) CLEARED!", subtitle: "\(engine.stage.name) Conquered")
            let items: [(String, () -> Void)] = [
                ("ENTER STAGE \(engine.stage.number + 1): \(PalaceStageCatalog.stages[nextStage].name)", { [weak self] in
                    guard let self = self else { return }
                    self.mode = .dungeonPlay
                    self.engine.loadStage(stageIndex: nextStage, preserveHealth: true)
                    self.selectMusicForStage(self.engine.stage)
                    self.menuLayer.removeAllChildren()
                    self.renderPlayfieldFrame()
                }),
                ("RETURN TO PALACE MENU", { [weak self] in self?.enterTitleMenu() })
            ]
            buildMenuColumn(items: items, centerX: 640, startY: 410, spacing: 62, width: 640)

        case .victoryEnding:
            addHeader("THE HOURGLASS CURSE IS SHATTERED!", subtitle: "Grand Vizier Zafar Is Defeated & Dawn Returns to the Palace!")
            let minsLeft = Int(engine.remainingSeconds) / 60
            let stat = CoreTextLabelRenderer.makeLabelNode("TIME REMAINING ON THE GOLDEN HOURGLASS: \(minsLeft) MINUTES", fontSize: 16, color: Palette.hdCyanMagic)
            stat.position = CGPoint(x: 640, y: 470)
            menuLayer.addChild(stat)
            buildMenuColumn(items: [
                ("PLAY AGAIN FROM STAGE 1", { [weak self] in self?.startNewEscape(fromStage: 0) }),
                ("RETURN TO PALACE MENU",   { [weak self] in self?.enterTitleMenu() })
            ], centerX: 640, startY: 370, spacing: 60, width: 520)

        case .gameOver:
            addHeader("FALLEN IN THE PALACE", subtitle: deathReason.isEmpty ? "The Sands Claimed Another Challenger" : deathReason)
            let curIdx = engine.stage.number - 1
            buildMenuColumn(items: [
                ("RETRY STAGE \(engine.stage.number) INSTANTLY", { [weak self] in
                    guard let self = self else { return }
                    if self.engine.isDuelArenaMode {
                        self.startQuickDuelArena(bout: 1)
                    } else {
                        self.mode = .dungeonPlay
                        self.engine.loadStage(stageIndex: curIdx, preserveHealth: true)
                        self.selectMusicForStage(self.engine.stage)
                        self.menuLayer.removeAllChildren()
                        self.renderPlayfieldFrame()
                    }
                }),
                ("RETURN TO PALACE MENU", { [weak self] in self?.enterTitleMenu() })
            ], centerX: 640, startY: 390, spacing: 60, width: 520)

        default:
            break
        }
    }

    private func addHeader(_ title: String, subtitle: String) {
        let t = CoreTextLabelRenderer.makeLabelNode(title, fontSize: 32, color: Palette.hdGold)
        t.position = CGPoint(x: 640, y: 606)
        menuLayer.addChild(t)
        let s = CoreTextLabelRenderer.makeLabelNode(subtitle, fontSize: 15, color: Palette.hdCyanMagic)
        s.position = CGPoint(x: 640, y: 566)
        menuLayer.addChild(s)
    }

    private func buildMenuColumn(items: [(String, () -> Void)], centerX: CGFloat, startY: CGFloat, spacing: CGFloat, width: CGFloat) {
        selectedMenuIndex = max(0, min(max(0, items.count - 1), selectedMenuIndex))
        for (idx, item) in items.enumerated() {
            let y = startY - CGFloat(idx) * spacing
            let r = CGRect(x: centerX - width * 0.5, y: y - 20, width: width, height: 40)
            let active = (idx == selectedMenuIndex)
            let bg = SKShapeNode(rectOf: r.size, cornerRadius: 10)
            bg.fillColor = active ? SKColor.rgba(0.96, 0.77, 0.27, 0.24) : SKColor.rgba(0.06, 0.10, 0.22, 0.86)
            bg.strokeColor = active ? Palette.hdGold : SKColor.rgba(0.35, 0.52, 0.82, 0.65)
            bg.lineWidth = active ? 2.6 : 1.5
            bg.position = CGPoint(x: centerX, y: y)
            menuLayer.addChild(bg)

            let lbl = CoreTextLabelRenderer.makeLabelNode(item.0, fontSize: 15, color: active ? Palette.hdGold : .white)
            lbl.position = CGPoint(x: centerX, y: y)
            menuLayer.addChild(lbl)

            menuButtons.append((rect: r, label: item.0, action: item.1))
        }
    }

    private func handlePointTap(_ pt: CGPoint) {
        if isPausedOverlay {
            if pt.y < 375 {
                isPausedOverlay = false
                enterTitleMenu()
            } else {
                isPausedOverlay = false
                renderPlayfieldFrame()
            }
            return
        }

        if mode == .titleMenu {
            let hgRect = CGRect(x: 805, y: 222, width: 280, height: 340)
            if hgRect.contains(pt) {
                hourglassEasterCount += 1
                AudioSynth.shared.playSFX(.mirrorShimmer)
                spawnSparkBurst(at: CGPoint(x: 945, y: 432), hex: 0xFFD966)
                showFloatingBanner("HOURGLASS BLESSING #\(hourglassEasterCount)!", hex: 0x38E8FF)
                return
            }
        }

        for (idx, btn) in menuButtons.enumerated() where btn.rect.contains(pt) {
            selectedMenuIndex = idx
            AudioSynth.shared.playSFX(.menuSelect)
            HapticsManager.tap()
            btn.action()
            return
        }
    }

    // MARK: - Platform Input Overrides

    #if os(macOS)
    override func keyDown(with event: NSEvent) {
        if event.isARepeat { return }
        let code = event.keyCode
        heldKeys.insert(code)

        if code == 9 { cycleVisualTheme(); return }  // V
        if code == 11 { cycleAudioChip(); return }   // B
        if code == 35 || code == 53 {                // P or ESC
            if mode == .dungeonPlay || mode == .duelArena {
                togglePauseFromUI()
            } else if mode != .titleMenu {
                enterTitleMenu()
            }
            return
        }
        if code == 46 && isPausedOverlay {           // M
            isPausedOverlay = false
            enterTitleMenu()
            return
        }

        if mode == .dungeonPlay || mode == .duelArena {
            if code == 49 || code == 7 { justPressedStrike = true }      // Space or X
            if code == 126 || code == 13 { justPressedJump = true }      // Up or W
        } else {
            if code == 126 || code == 13 {
                selectedMenuIndex = max(0, selectedMenuIndex - 1)
                AudioSynth.shared.playSFX(.footstep)
                renderStaticMenuScreen()
            } else if code == 125 || code == 1 {
                selectedMenuIndex = min(max(0, menuButtons.count - 1), selectedMenuIndex + 1)
                AudioSynth.shared.playSFX(.footstep)
                renderStaticMenuScreen()
            } else if code == 36 || code == 49 {
                if selectedMenuIndex < menuButtons.count {
                    AudioSynth.shared.playSFX(.menuSelect)
                    menuButtons[selectedMenuIndex].action()
                }
            }
        }
    }

    override func keyUp(with event: NSEvent) {
        heldKeys.remove(event.keyCode)
    }

    override func mouseDown(with event: NSEvent) {
        let pt = event.location(in: self)
        if mode == .dungeonPlay || mode == .duelArena, !isPausedOverlay {
            justPressedStrike = true
        } else {
            handlePointTap(pt)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if mode == .dungeonPlay || mode == .duelArena, !isPausedOverlay {
            justPressedJump = true
        }
    }
    #else
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        handlePointTap(t.location(in: self))
    }
    #endif

    // MARK: - Deterministic Retina App Store Screenshot Stager & 60fps Trailer Autopilot

    func stageAppStoreScreenshot(index: Int, isMobile: Bool) {
        isPausedOverlay = false
        fxLayer.removeAllChildren()
        bannerNode?.removeFromParent()
        bannerNode = nil

        PersistenceManager.shared.updateSettings {
            $0.visualTheme = (index == 5) ? .retro1989 : .hdOverdrive
            $0.audioChip = (index == 5) ? .retroAdLib : .modernSynth
        }
        refreshCRTOverlay()

        switch index {
        case 1:
            // Moonlit Palace Courtyard mid-leap scimitar clash over spikes!
            mode = .dungeonPlay
            engine = DungeonEngine(stageIndex: 2, carryMaxHP: 5)
            engine.currentRoomValueForStaging(room: 0, heroX: 520, heroY: 208, pose: .swordSlash, hp: 5, remSec: 3290)
            engine.stageEnemy(index: 0, x: 604, pose: .swordParry, hp: 3)
            animClock = 1.2
            renderPlayfieldFrame()
            spawnSparkBurst(at: CGPoint(x: 564, y: 248), hex: 0xFFD966)
            showFloatingBanner("STEEL RIPOSTE! CAPTAIN STAGGERED!", hex: 0xFFD966)

        case 2:
            // Grand Vizier Zafar's Hourglass Sanctum Showdown!
            mode = .dungeonPlay
            engine = DungeonEngine(stageIndex: 5, carryMaxHP: 6)
            engine.currentRoomValueForStaging(room: 1, heroX: 535, heroY: 178, pose: .swordParry, hp: 5, remSec: 745)
            engine.stageEnemy(index: 0, x: 625, pose: .swordSlash, hp: 4)
            animClock = 2.4
            renderPlayfieldFrame()
            spawnSparkBurst(at: CGPoint(x: 580, y: 228), hex: 0x38E8FF)
            showFloatingBanner("VIZIER ZAFAR'S THRONE OF THE HOURGLASS", hex: 0x38E8FF)

        case 3:
            // Catacombs of Bone — Immortal Skeleton + Guillotine Chopper!
            mode = .dungeonPlay
            engine = DungeonEngine(stageIndex: 1, carryMaxHP: 4)
            engine.chopperClock = 0.78
            engine.currentRoomValueForStaging(room: 1, heroX: 580, heroY: 338, pose: .swordSlash, hp: 4, remSec: 2810)
            engine.stageEnemy(index: 0, x: 668, pose: .swordGuard, hp: 2)
            animClock = 3.1
            renderPlayfieldFrame()
            showFloatingBanner("PARRY THE SKELETON CAPTAIN INTO THE CHASM!", hex: 0xF6C445)

        case 4:
            // Hall of the Silver Mirror & Emerald Feather Aura!
            mode = .dungeonPlay
            engine = DungeonEngine(stageIndex: 3, carryMaxHP: 5)
            engine.featherTimer = 8.0
            engine.currentRoomValueForStaging(room: 1, heroX: 495, heroY: 368, pose: .jumpArc, hp: 5, remSec: 2150)
            animClock = 4.0
            renderPlayfieldFrame()
            spawnSparkBurst(at: CGPoint(x: 592, y: 392), hex: 0x38E8FF)
            showFloatingBanner("LEAP THROUGH THE SHIMMERING SILVER MIRROR!", hex: 0x2FE388)

        case 5:
            // Live 1989 EGA 16-Color Pixel & AdLib FM Retro Mode!
            mode = .dungeonPlay
            engine = DungeonEngine(stageIndex: 0, carryMaxHP: 4)
            engine.chopperClock = 0.82
            engine.currentRoomValueForStaging(room: 1, heroX: 510, heroY: 178, pose: .swordGuard, hp: 4, remSec: 3480)
            engine.stageEnemy(index: 0, x: 598, pose: .swordSlash, hp: 2)
            animClock = 5.2
            renderPlayfieldFrame()
            showFloatingBanner("LIVE 1989 EGA PIXEL & ADLIB FM MODE", hex: 0x38E8FF)

        default:
            enterTitleMenu()
        }
    }

    func applyTrailerAutopilot(frame: Int, includeTitleIntro: Bool) {
        let dt: CGFloat = 1.0 / 60.0
        animClock += dt

        if includeTitleIntro {
            if frame == 0 {
                PersistenceManager.shared.updateSettings {
                    $0.visualTheme = .hdOverdrive
                    $0.audioChip = .modernSynth
                }
                refreshCRTOverlay()
                enterTitleMenu()
                return
            }
            if frame < 150 {
                if frame == 60 || frame == 110 {
                    selectedMenuIndex = (frame == 60) ? 1 : 0
                    AudioSynth.shared.playSFX(.footstep)
                    renderStaticMenuScreen()
                }
                return
            }
            if frame == 150 {
                startNewEscape(fromStage: 2)
                return
            }
        } else {
            if frame == 0 {
                PersistenceManager.shared.updateSettings {
                    $0.visualTheme = .hdOverdrive
                    $0.audioChip = .modernSynth
                }
                refreshCRTOverlay()
                startNewEscape(fromStage: 2)
            } else if frame == 300 {
                startNewEscape(fromStage: 1)
                engine.currentRoomValueForStaging(room: 1, heroX: 350, heroY: 338, pose: .runA, hp: 4, remSec: 2700)
            } else if frame == 560 {
                startNewEscape(fromStage: 5)
                engine.currentRoomValueForStaging(room: 1, heroX: 390, heroY: 178, pose: .swordGuard, hp: 5, remSec: 920)
            } else if frame == 720 {
                PersistenceManager.shared.updateSettings {
                    $0.visualTheme = .retro1989
                    $0.audioChip = .retroAdLib
                }
                AudioSynth.shared.setChipMode(.retroAdLib)
                refreshCRTOverlay()
                showFloatingBanner("1989 EGA PIXEL & ADLIB FM MODE", hex: 0x38E8FF)
            }
        }

        // Smart fencing + acrobatics autopilot
        var mx: CGFloat = 1.0
        var strike = false
        var jump = false
        if let foe = engine.activeEnemyInCurrentRoom() {
            let d = foe.x - engine.heroX
            mx = (abs(d) > 74) ? (d > 0 ? 1 : -1) : 0
            if frame % 34 == 0 { jump = true }
            if frame % 22 == 10 { strike = true }
        } else {
            if frame % 75 == 20 { jump = true }
        }

        let evs = engine.step(dt: dt, moveX: mx, moveY: 0, sneakHeld: false, strikePressed: strike, jumpOrParryPressed: jump, relaxedTimer: false)
        processEvents(evs)
        if mode != .dungeonPlay {
            startNewEscape(fromStage: 2)
        }
        renderPlayfieldFrame()
    }
}

extension DungeonEngine {
    func currentRoomValueForStaging(room: Int, heroX: CGFloat, heroY: CGFloat, pose: HeroPose, hp: Int, remSec: Double) {
        self.setStagingRoom(room)
        self.heroX = heroX
        self.heroY = heroY
        self.heroPose = pose
        self.heroHasSword = true
        self.heroHP = min(heroMaxHP, hp)
        self.remainingSeconds = remSec
    }

    private func setStagingRoom(_ r: Int) {
        guard !mutableRooms.isEmpty else { return }
        currentRoom = max(0, min(mutableRooms.count - 1, r))
    }

    func stageEnemy(index: Int, x: CGFloat, pose: HeroPose, hp: Int) {
        let roomEnemies = enemies.indices.filter { enemies[$0].room == currentRoom }
        guard index < roomEnemies.count else { return }
        let idx = roomEnemies[index]
        enemies[idx].x = x
        enemies[idx].facing = (heroX <= x) ? -1 : 1
        enemies[idx].pose = pose
        enemies[idx].hp = hp
        enemies[idx].defeated = false
    }
}
