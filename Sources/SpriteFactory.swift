import Foundation
import CoreGraphics
import SpriteKit

@MainActor
final class SpriteFactory {
    static let shared = SpriteFactory()
    private var cache: [String: SKTexture] = [:]

    func clearCache() {
        cache.removeAll()
    }

    private func cached(_ key: String, size: CGSize, pixelated: Bool, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let hit = cache[key] { return hit }
        let w = max(4, Int(size.width))
        let h = max(4, Int(size.height))
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: info) else {
            return SKTexture()
        }
        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
        if pixelated {
            ctx.interpolationQuality = .none
            ctx.setShouldAntialias(false)
        } else {
            ctx.interpolationQuality = .high
            ctx.setShouldAntialias(true)
        }
        draw(ctx, CGSize(width: CGFloat(w), height: CGFloat(h)))
        guard let cg = ctx.makeImage() else { return SKTexture() }
        let tex = SKTexture(cgImage: cg)
        tex.filteringMode = pixelated ? .nearest : .linear
        cache[key] = tex
        return tex
    }

    // MARK: - Rotoscope-Inspired Acrobat Hero & Palace Guards / Skeleton / Grand Vizier

    func fighterTexture(
        isHero: Bool,
        archetype: EnemyArchetype = .dungeonGuard,
        pose: HeroPose,
        hasSword: Bool,
        retro: Bool
    ) -> SKTexture {
        let key = "f_\(isHero)_\(archetype.rawValue)_\(pose.rawValue)_\(hasSword)_\(retro)"
        let size = retro ? CGSize(width: 40, height: 52) : CGSize(width: 80, height: 104)
        return cached(key, size: size, pixelated: retro) { ctx, sz in
            let s = sz.width / 80.0
            ctx.scaleBy(x: s, y: s)

            let isSkeleton = (!isHero && archetype == .skeletonKnight)
            let isPhantom  = (!isHero && archetype == .shadowPhantom)
            let alpha: CGFloat = isPhantom ? 0.72 : 1.0

            let skin = isSkeleton ? SKColor.hex(0xE8EEF5, alpha: alpha)
                : (isPhantom ? SKColor.hex(0x9CF5FF, alpha: alpha) : SKColor.hex(0xE4A672, alpha: alpha))
            let tunic = isHero
                ? (retro ? Palette.egaWhite : SKColor.hex(0xF7F1E3, alpha: alpha))
                : SKColor.hex(archetype.tunicHex, alpha: alpha)
            let sash = isHero
                ? (retro ? Palette.egaBrightRed : Palette.hdCrimson)
                : SKColor.hex(archetype.sashHex, alpha: alpha)
            let pants = isHero
                ? SKColor.hex(isPhantom ? 0x2AB8DF : 0xEFE6D5, alpha: alpha)
                : SKColor.hex(0x1E2538, alpha: alpha)
            let boots = SKColor.hex(0x6C3B1E, alpha: alpha)

            let crouchY: CGFloat = (pose == .sneak) ? -12 : 0
            let hangY: CGFloat   = (pose == .ledgeHang) ? 8 : 0
            let bodyY: CGFloat   = 38 + crouchY + hangY

            // Soft ground shadow
            if pose != .jumpArc && pose != .ledgeHang && !retro {
                ctx.setFillColor(SKColor.rgba(0, 0, 0, 0.34).cgColor)
                ctx.fillEllipse(in: CGRect(x: 18, y: 3, width: 44, height: 10))
            }

            // Flowing crimson/gold sash tails
            ctx.setFillColor(sash.cgColor)
            let sashWave: CGFloat = (pose == .runA || pose == .jumpArc) ? -10 : -4
            ctx.fill(CGRect(x: 22 + sashWave, y: bodyY + 4, width: 14, height: 6))
            ctx.fill(CGRect(x: 18 + sashWave, y: bodyY - 2, width: 12, height: 5))

            // Legs (kinematic stride based on pose)
            let leftLegX: CGFloat
            let rightLegX: CGFloat
            let legH: CGFloat = (pose == .sneak) ? 18 : 26
            switch pose {
            case .runA:       leftLegX = 24; rightLegX = 48
            case .runB:       leftLegX = 46; rightLegX = 26
            case .jumpArc:    leftLegX = 22; rightLegX = 50
            case .swordSlash: leftLegX = 24; rightLegX = 52
            case .swordGuard, .swordParry: leftLegX = 27; rightLegX = 47
            default:          leftLegX = 31; rightLegX = 41
            }

            ctx.setFillColor(pants.cgColor)
            ctx.fill(CGRect(x: leftLegX, y: 12, width: 10, height: legH))
            ctx.fill(CGRect(x: rightLegX, y: 12, width: 10, height: legH))

            // Boots
            ctx.setFillColor(boots.cgColor)
            ctx.fill(CGRect(x: leftLegX - 1, y: 6, width: 13, height: 8))
            ctx.fill(CGRect(x: rightLegX - 1, y: 6, width: 13, height: 8))

            // Torso / Flowing Tunic
            ctx.setFillColor(tunic.cgColor)
            ctx.fill(CGRect(x: 27, y: bodyY - 2, width: 26, height: 28))
            if isSkeleton {
                // Ribcage stripes
                ctx.setFillColor(SKColor.hex(0x2B3348).cgColor)
                for ry in stride(from: bodyY + 4, through: bodyY + 18, by: 6) {
                    ctx.fill(CGRect(x: 31, y: ry, width: 18, height: 2.5))
                }
            } else {
                // V-collar & waist sash
                ctx.setFillColor(sash.cgColor)
                ctx.fill(CGRect(x: 26, y: bodyY + 1, width: 28, height: 7))
                if !isHero {
                    // Ornate breastplate trim for guards/vizier
                    ctx.setFillColor(Palette.hdGold.cgColor)
                    ctx.fill(CGRect(x: 30, y: bodyY + 10, width: 20, height: 3))
                }
            }

            // Cape for Grand Vizier
            if !isHero && archetype == .grandVizier {
                ctx.setFillColor(SKColor.hex(0x3D0E75).cgColor)
                ctx.fill(CGRect(x: 16, y: 14, width: 13, height: 48))
            }

            // Head & Hair / Turban / Crown
            let headY = bodyY + 26
            ctx.setFillColor(skin.cgColor)
            ctx.fillEllipse(in: CGRect(x: 31, y: headY, width: 18, height: 19))

            // Eye
            ctx.setFillColor((isSkeleton ? Palette.hdCrimson : SKColor.hex(0x141824)).cgColor)
            ctx.fill(CGRect(x: 43, y: headY + 9, width: 3.5, height: 3.5))

            if isHero {
                // Flowing dark Arabian hair + crimson headband
                ctx.setFillColor(SKColor.hex(0x1B1F2E, alpha: alpha).cgColor)
                ctx.fill(CGRect(x: 28, y: headY + 11, width: 21, height: 9))
                ctx.fill(CGRect(x: 26, y: headY + 4, width: 7, height: 11))
                ctx.setFillColor(sash.cgColor)
                ctx.fill(CGRect(x: 29, y: headY + 12, width: 20, height: 3.5))
            } else if !isSkeleton {
                // Royal Turban + Jewel plume
                let turbanCol = (archetype == .grandVizier) ? SKColor.hex(0x220B44) : SKColor.hex(0xF3EAD6)
                ctx.setFillColor(turbanCol.cgColor)
                ctx.fillEllipse(in: CGRect(x: 28, y: headY + 10, width: 24, height: 14))
                ctx.setFillColor(Palette.hdGold.cgColor)
                ctx.fillEllipse(in: CGRect(x: 41, y: headY + 13, width: 6, height: 7))
            }

            // Arms & Curved Golden Scimitar
            ctx.setFillColor(tunic.cgColor)
            if pose == .ledgeHang {
                ctx.fill(CGRect(x: 34, y: headY + 8, width: 10, height: 20))
                ctx.setFillColor(skin.cgColor)
                ctx.fill(CGRect(x: 35, y: headY + 26, width: 9, height: 6))
            } else if pose == .drinkPotion {
                ctx.fill(CGRect(x: 44, y: bodyY + 14, width: 14, height: 8))
                ctx.setFillColor(Palette.hdCrimson.cgColor)
                ctx.fillEllipse(in: CGRect(x: 54, y: headY + 2, width: 10, height: 12))
            } else if hasSword && (pose == .swordGuard || pose == .swordSlash || pose == .swordParry) {
                let armLen: CGFloat = (pose == .swordSlash) ? 22 : 14
                let armY: CGFloat   = (pose == .swordParry) ? (bodyY + 20) : (bodyY + 12)
                ctx.fill(CGRect(x: 46, y: armY, width: armLen, height: 8))

                // Golden Crossguard Hilt
                let hiltX = 46 + armLen
                ctx.setFillColor(Palette.hdGold.cgColor)
                ctx.fill(CGRect(x: hiltX - 2, y: armY - 3, width: 5, height: 14))

                // Gleaming Curved Scimitar Blade
                let bladeColor = isPhantom ? Palette.hdCyanMagic : SKColor.hex(0xEAF4FF)
                ctx.setStrokeColor(bladeColor.cgColor)
                ctx.setLineWidth(4.2)
                ctx.beginPath()
                ctx.move(to: CGPoint(x: hiltX + 2, y: armY + 4))
                if pose == .swordSlash {
                    ctx.addQuadCurve(to: CGPoint(x: hiltX + 28, y: armY + 10), control: CGPoint(x: hiltX + 16, y: armY - 2))
                } else if pose == .swordParry {
                    ctx.addQuadCurve(to: CGPoint(x: hiltX + 12, y: armY + 30), control: CGPoint(x: hiltX + 18, y: armY + 14))
                } else {
                    ctx.addQuadCurve(to: CGPoint(x: hiltX + 20, y: armY + 24), control: CGPoint(x: hiltX + 16, y: armY + 8))
                }
                ctx.strokePath()
            } else {
                // Acrobat running / idle arm
                let swing: CGFloat = (pose == .runA) ? 10 : -4
                ctx.fill(CGRect(x: 42 + swing * 0.4, y: bodyY + 10, width: 14, height: 8))
            }
        }
    }

    // MARK: - Palace & Dungeon Architecture, Traps, Potions & Hourglass

    func stoneBlockTexture(biome: PalaceBiome, loose: Bool, retro: Bool) -> SKTexture {
        let key = "stone_\(biome.rawValue)_\(loose)_\(retro)"
        return cached(key, size: CGSize(width: 96, height: 32), pixelated: retro) { ctx, sz in
            let base: SKColor
            let topLit: SKColor
            if retro {
                base = (biome == .moonlitCourtyard || biome == .vizierSanctum) ? Palette.egaBrown : Palette.egaDarkGray
                topLit = (biome == .moonlitCourtyard || biome == .vizierSanctum) ? Palette.egaYellow : Palette.egaLightGray
            } else {
                switch biome {
                case .sunkenDungeon:    base = Palette.hdDungeonSlate; topLit = Palette.hdDungeonLit
                case .undeadCatacombs:  base = SKColor.hex(0x3B3348);  topLit = SKColor.hex(0x635878)
                case .moonlitCourtyard: base = Palette.hdSandstone;    topLit = Palette.hdSandstoneLit
                case .mirrorHall:       base = SKColor.hex(0x354B6E);  topLit = SKColor.hex(0x6EA0D8)
                case .astralBridge:     base = SKColor.hex(0x234E68);  topLit = Palette.hdCyanMagic
                case .vizierSanctum:    base = SKColor.hex(0x5E2B44);  topLit = Palette.hdGold
                }
            }

            ctx.setFillColor(base.cgColor)
            ctx.fill(CGRect(x: 1, y: 2, width: sz.width - 2, height: sz.height - 4))
            ctx.setFillColor(topLit.cgColor)
            ctx.fill(CGRect(x: 1, y: sz.height - 8, width: sz.width - 2, height: 6))

            // Mortar & crack lines
            ctx.setStrokeColor(SKColor.rgba(0, 0, 0, 0.55).cgColor)
            ctx.setLineWidth(2.0)
            ctx.stroke(CGRect(x: 1, y: 2, width: sz.width - 2, height: sz.height - 4))
            ctx.move(to: CGPoint(x: 48, y: 2))
            ctx.addLine(to: CGPoint(x: 48, y: sz.height - 8))
            ctx.strokePath()

            if loose {
                ctx.setStrokeColor(Palette.hdGold.cgColor)
                ctx.setLineWidth(2.2)
                ctx.move(to: CGPoint(x: 20, y: 6))
                ctx.addLine(to: CGPoint(x: 34, y: 20))
                ctx.addLine(to: CGPoint(x: 62, y: 8))
                ctx.addLine(to: CGPoint(x: 78, y: 22))
                ctx.strokePath()
            }
        }
    }

    func spikesTexture(extended: Bool, retro: Bool) -> SKTexture {
        let key = "spikes_\(extended)_\(retro)"
        return cached(key, size: CGSize(width: 88, height: 48), pixelated: retro) { ctx, _ in
            let spikeH: CGFloat = extended ? 38 : 10
            let steel = retro ? Palette.egaWhite : SKColor.hex(0xDCE6F2)
            let edge  = retro ? Palette.egaLightGray : SKColor.hex(0x7B8BA4)

            ctx.setFillColor(SKColor.hex(0x1E2433).cgColor)
            ctx.fill(CGRect(x: 4, y: 0, width: 80, height: 7))

            for i in 0..<5 {
                let bx = CGFloat(10 + i * 16)
                ctx.beginPath()
                ctx.move(to: CGPoint(x: bx, y: 6))
                ctx.addLine(to: CGPoint(x: bx + 6, y: 6 + spikeH))
                ctx.addLine(to: CGPoint(x: bx + 12, y: 6))
                ctx.closePath()
                ctx.setFillColor(steel.cgColor)
                ctx.fillPath()

                ctx.beginPath()
                ctx.move(to: CGPoint(x: bx + 6, y: 6 + spikeH))
                ctx.addLine(to: CGPoint(x: bx + 12, y: 6))
                ctx.addLine(to: CGPoint(x: bx + 6, y: 6))
                ctx.closePath()
                ctx.setFillColor(edge.cgColor)
                ctx.fillPath()
            }
        }
    }

    func chopperTexture(closedRatio: CGFloat, retro: Bool) -> SKTexture {
        let bucket = Int((closedRatio * 4).rounded())
        let key = "chopper_\(bucket)_\(retro)"
        return cached(key, size: CGSize(width: 56, height: 150), pixelated: retro) { ctx, sz in
            // Iron frame slot
            ctx.setFillColor(SKColor.hex(0x283044).cgColor)
            ctx.fill(CGRect(x: 22, y: 0, width: 12, height: sz.height))

            let gap = (1.0 - CGFloat(bucket) / 4.0) * 52.0
            let steel = retro ? Palette.egaBrightCyan : SKColor.hex(0xE4EEF8)
            let crimsonEdge = Palette.hdCrimson

            // Upper crescent blade descending from top
            let topBladeBottom = sz.height * 0.5 + gap * 0.5
            ctx.setFillColor(steel.cgColor)
            ctx.fill(CGRect(x: 10, y: topBladeBottom, width: 36, height: sz.height - topBladeBottom - 4))
            ctx.setFillColor(crimsonEdge.cgColor)
            ctx.fill(CGRect(x: 10, y: topBladeBottom, width: 36, height: 5))

            // Lower crescent blade rising from floor
            let botBladeTop = sz.height * 0.5 - gap * 0.5
            ctx.setFillColor(steel.cgColor)
            ctx.fill(CGRect(x: 10, y: 4, width: 36, height: max(4, botBladeTop - 4)))
            ctx.setFillColor(crimsonEdge.cgColor)
            ctx.fill(CGRect(x: 10, y: max(4, botBladeTop - 5), width: 36, height: 5))
        }
    }

    func portcullisTexture(openRatio: CGFloat, retro: Bool) -> SKTexture {
        let bucket = Int((openRatio * 5).rounded())
        let key = "gate_\(bucket)_\(retro)"
        return cached(key, size: CGSize(width: 36, height: 150), pixelated: retro) { ctx, sz in
            let barBottom = (CGFloat(bucket) / 5.0) * 112.0
            let h = max(14, sz.height - barBottom)
            let iron = retro ? Palette.egaLightGray : SKColor.hex(0x9BAAC2)
            ctx.setFillColor(iron.cgColor)
            for x in [6, 15, 24] {
                ctx.fill(CGRect(x: CGFloat(x), y: barBottom, width: 5, height: h))
            }
            ctx.fill(CGRect(x: 3, y: barBottom + 8, width: 30, height: 6))
            ctx.fill(CGRect(x: 3, y: sz.height - 10, width: 30, height: 8))
        }
    }

    func torchTexture(frame: Int, retro: Bool) -> SKTexture {
        let key = "torch_\(frame % 2)_\(retro)"
        return cached(key, size: CGSize(width: 44, height: 76), pixelated: retro) { ctx, _ in
            // Brass sconce
            ctx.setFillColor(Palette.hdGold.cgColor)
            ctx.fill(CGRect(x: 18, y: 8, width: 8, height: 28))
            ctx.fill(CGRect(x: 13, y: 32, width: 18, height: 6))

            // Outer amber glow + inner bright flame
            let sway: CGFloat = (frame % 2 == 0) ? -2.5 : 2.5
            if !retro {
                ctx.setFillColor(SKColor.rgba(1.0, 0.58, 0.14, 0.28).cgColor)
                ctx.fillEllipse(in: CGRect(x: 2, y: 30, width: 40, height: 42))
            }
            ctx.setFillColor(SKColor.hex(0xFF7B1C).cgColor)
            ctx.fillEllipse(in: CGRect(x: 11 + sway, y: 38, width: 22, height: 28))
            ctx.setFillColor(SKColor.hex(0xFFF066).cgColor)
            ctx.fillEllipse(in: CGRect(x: 15 + sway * 0.5, y: 40, width: 14, height: 18))
        }
    }

    func potionTexture(kind: TileFeature, retro: Bool) -> SKTexture {
        let key = "pot_\(String(describing: kind))_\(retro)"
        return cached(key, size: CGSize(width: 38, height: 46), pixelated: retro) { ctx, _ in
            let liquid: SKColor = {
                switch kind {
                case .potionMaxLife: return Palette.hdGold
                case .potionFeather: return Palette.hdEmerald
                default:             return Palette.hdCrimson
                }
            }()
            // Glass bulb
            ctx.setFillColor(liquid.cgColor)
            ctx.fillEllipse(in: CGRect(x: 7, y: 4, width: 24, height: 24))
            ctx.setStrokeColor(SKColor.white.cgColor)
            ctx.setLineWidth(2.2)
            ctx.strokeEllipse(in: CGRect(x: 7, y: 4, width: 24, height: 24))
            // Neck & cork
            ctx.setFillColor(SKColor.hex(0xCFE8FF).cgColor)
            ctx.fill(CGRect(x: 15, y: 26, width: 8, height: 9))
            ctx.setFillColor(Palette.hdGold.cgColor)
            ctx.fill(CGRect(x: 13, y: 34, width: 12, height: 5))
        }
    }

    func hourglassPropTexture(retro: Bool) -> SKTexture {
        let key = "hourglass_\(retro)"
        return cached(key, size: CGSize(width: 110, height: 160), pixelated: retro) { ctx, _ in
            // Cyan-gold magical aura
            if !retro {
                ctx.setFillColor(SKColor.rgba(0.22, 0.91, 1.0, 0.20).cgColor)
                ctx.fillEllipse(in: CGRect(x: 6, y: 16, width: 98, height: 128))
            }
            // Top & bottom golden caps + pillars
            ctx.setFillColor(Palette.hdGold.cgColor)
            ctx.fill(CGRect(x: 18, y: 8, width: 74, height: 12))
            ctx.fill(CGRect(x: 18, y: 140, width: 74, height: 12))
            ctx.fill(CGRect(x: 22, y: 20, width: 7, height: 120))
            ctx.fill(CGRect(x: 81, y: 20, width: 7, height: 120))

            // Glass bulbs
            ctx.setFillColor(SKColor.rgba(0.35, 0.88, 1.0, 0.42).cgColor)
            ctx.fillEllipse(in: CGRect(x: 31, y: 82, width: 48, height: 56))
            ctx.fillEllipse(in: CGRect(x: 31, y: 22, width: 48, height: 56))

            // Trickling luminous sand
            ctx.setFillColor(SKColor.hex(0xFFD447).cgColor)
            ctx.fillEllipse(in: CGRect(x: 36, y: 86, width: 38, height: 22))
            ctx.fill(CGRect(x: 53, y: 38, width: 4, height: 50))
            ctx.fillEllipse(in: CGRect(x: 34, y: 24, width: 42, height: 24))
        }
    }

    func scanlineOverlayTexture() -> SKTexture {
        cached("crt_scanlines_mb", size: CGSize(width: 64, height: 64), pixelated: true) { ctx, sz in
            for y in stride(from: 0, to: Int(sz.height), by: 4) {
                ctx.setFillColor(SKColor.rgba(0, 0, 0, 0.28).cgColor)
                ctx.fill(CGRect(x: 0, y: y, width: Int(sz.width), height: 2))
            }
        }
    }
}
