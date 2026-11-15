import AppKit
import CoreGraphics
import ImageIO
import Foundation

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("Usage: make_onepagers_pdf <project_dir>\n", stderr)
    exit(1)
}

let projectDir = URL(fileURLWithPath: args[1], isDirectory: true)

func loadCGImage(_ relPath: String) -> CGImage? {
    let url = projectDir.appendingPathComponent(relPath)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

let bannerImg = loadCGImage("Marketing/storefront_banner.png")
let iconImg   = loadCGImage("Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png")
let shotDuel  = loadCGImage("dist/AppStore_Assets/Mac_2560x1600/01_moonlit_scimitar_duel.jpg")
let shotViz   = loadCGImage("dist/AppStore_Assets/Mac_2560x1600/02_vizier_hourglass_showdown.jpg")
let shotCat   = loadCGImage("dist/AppStore_Assets/Mac_2560x1600/03_catacombs_skeleton_chopper.jpg")

struct SheetCopy {
    let outName: String
    let subtitle: String
    let pills: [String]
    let leftTitle: String
    let leftBody: String
    let rightTitle: String
    let rightBody: String
    let stripTitle: String
    let cards: [(String, String, String)]
    let shotCaptions: [String]
    let footLeftTitle: String
    let footLeftBody: String
    let footRightTitle: String
    let footRightBody: String
}

let enCopy = SheetCopy(
    outName: "MirageBlade_OnePager_EN.pdf",
    subtitle: "A 120Hz Kinematic Tribute to the 1989 Arabian Dungeon Action Classic  •  © 2026 NGD",
    pills: [
        "iPhone • iPad • Mac Universal",
        "60-Min Hourglass + Relax Mode",
        "1989 EGA + AdLib FM Synth",
        "Launch Sale $3.99 (Reg $6.99)"
    ],
    leftTitle: "BEAT THE GOLDEN HOURGLASS!",
    leftBody: "Sprint, leap chasms, grab stone ledges, tiptoe across concealed floor spikes, and cross gleaming curved scimitars before the final grain of sand falls!\n\n• Tactical Steel Parries: Time your parry [UP / LEAP] as a guard swings to spark gold and unleash a 2x Riposte!\n• Live Era Switch [V / B]: Morph instantly between 120Hz HD Palace Art and 1989 EGA 16-Color Pixel + AdLib FM!",
    rightTitle: "6 PALACE & DUNGEON CHAPTERS",
    rightBody: "• SUNKEN DUNGEON & BONE CATACOMBS: Claim the Golden Scimitar, dash guillotine jaws & knock the Skeleton into pits!\n• MOONLIT COURTYARD & MIRROR HALL: Drink Ruby/Gold/Emerald elixirs & leap through the Silver Magic Mirror!\n• SHADOW SPIRE & VIZIER SANCTUM: Reunite with your Phantom & defeat Grand Vizier Zafar at the Hourglass!",
    stripTitle: "SIX PILLARS OF MIRAGE BLADE — ACROBATICS, PARRIES, TRAPS & 1989 TIME-MACHINE",
    cards: [
        ("ACROBATICS", "Broad leaps, ledge grabs & sneak", "120HZ FLUID"),
        ("RIPOSTES", "Timed scimitar parries & sparks", "1V1 FENCING"),
        ("DEATHTRAPS", "Spikes, choppers & loose slabs!", "PRECISION"),
        ("ELIXIRS", "Ruby heal, Gold life & Feather!", "3 POTIONS"),
        ("MIRROR", "Face & merge with your Phantom", "STAGE 4–5"),
        ("1989 EGA", "16-color pixel + AdLib OPL2 FM", "LIVE [V / B]")
    ],
    shotCaptions: [
        "MOONLIT COURTYARD SCIMITAR RIPOSTE",
        "GRAND VIZIER HOURGLASS SHOWDOWN",
        "CATACOMBS SKELETON & CHOPPER JAWS"
    ],
    footLeftTitle: "UNIVERSAL CONTROLS & ARENA MODES",
    footLeftBody: "• iPhone & iPad: Virtual Stick + SLASH & LEAP/PARRY + Haptics\n• Mac: Keyboard (Arrows/WASD, Shift Sneak, Space, V & B)\n• Quick Scimitar Duel Tournament + Optional Relaxed Timer\n• Native PS5 DualSense, Xbox & MFi Bluetooth Gamepads",
    footRightTitle: "PRODUCT & APP STORE FACTSHEET",
    footRightBody: "• Developer & Publisher: NGD (Bundle ID: com.ngd.mirageblade)\n• 100% Original IP, Palace Art, Code & Hijaz/AdLib Synth\n• Platforms: iOS 16+, iPadOS 16+, macOS 14+ Universal 2\n• Business Model: Pay-Once Universal • Zero Ads • Zero IAP"
)

let huCopy = SheetCopy(
    outName: "MirageBlade_Egyoldalas_Jatekleiras.pdf",
    subtitle: "120Hz-es tisztelgés az 1989-es kazamatás-kardvívós akcióklasszikus előtt  •  © 2026 NGD",
    pills: [
        "iPhone • iPad • Mac",
        "60 Perces Homokóra + Relax",
        "1989 EGA + AdLib FM Hang",
        "Akció: $3.99 ($6.99)"
    ],
    leftTitle: "GYŐZD LE AZ ARANY HOMOKÓRÁT!",
    leftBody: "Ugorj át szakadékokat, kapaszkodj fel sziklaperemekre, lopakodj át a rejtett padlótüskéken, és vívj pengeszikrázó szablyapárbajokat, mielőtt lepereg az utolsó homokszem!\n\n• Taktikai Hárítás & Riposzt: Védd ki [FEL / LEAP] az őr csapását, majd vigyél be duplasebzésű visszavágást!\n• Élő Időgép [V / B]: Válts bármikor a 120Hz HD Palota és az 1989-es 16-színű EGA pixel + AdLib FM között!",
    rightTitle: "6 PALOTA ÉS KAZAMATA FEJEZET",
    rightBody: "• KAZAMATA & CSONTKATAKOMBA: Szerezd meg az Arany Szablyát, száguldj át a bárdok közt, lökd szakadékba a Csontvázat!\n• HOLDFÉNYES UDVAR & TÜKÖRTEREM: Igyál Rubin/Arany/Smaragd elixírt, és ugorj át az Ezüst Varázstükrön!\n• ÁRNYHÍD & NAGYVEZÍR SZENTÉLY: Egyesülj tükörképeddel, és győzd le Zafart a hatalmas Arany Homokóra előtt!",
    stripTitle: "A MIRAGE BLADE HAT PILLÉRE — AKROBATIKA, SZABLYAVÍVÁS, CSAPDÁK ÉS RETRO IDŐGÉP",
    cards: [
        ("AKROBATIKA", "Szakadékugrás, peremfogás & séta", "120HZ SIMA"),
        ("SZABLYADUEL", "Időzített hárítás & acélriposzt", "1V1 VÍVÁS"),
        ("CSAPDÁK", "Tüskék, guillotine-bárd & laza kő", "PRECÍZIÓ"),
        ("ELIXÍREK", "Rubin élet, Arany max & Lebegés", "3 VARÁZSITAL"),
        ("TÜKÖRKÉP", "Hasonmás idézés & fényhíd-fúzió", "4–5. PÁLYA"),
        ("1989 EGA", "16-színű pixel + AdLib OPL2 FM", "ÉLŐ [V / B]")
    ],
    shotCaptions: [
        "HOLDFÉNYES UDVARI SZABLYAPÁRBAJ",
        "ZAFAR NAGYVEZÍR HOMOKÓRA-DÖNTŐ",
        "KATAKOMBA CSONTVÁZ ÉS ACÉLBÁRD"
    ],
    footLeftTitle: "UNIVERZÁLIS IRÁNYÍTÁS & PÁRBAJ ARÉNA",
    footLeftBody: "• iPhone & iPad: Virtuális kar + SLASH & LEAP + Haptika\n• Mac: Billentyűzet (Nyilak/WASD, Shift séta, Space, V & B)\n• Gyors Szablyapárbaj Bajnokság + Kikapcsolható időkorlát\n• Natív PS5 DualSense, Xbox és MFi Bluetooth kontrollerek",
    footRightTitle: "TERMÉK & APP STORE ADATLAP",
    footRightBody: "• Fejlesztő & Kiadó: NGD (Bundle ID: com.ngd.mirageblade)\n• 100% Eredeti IP, Palota-Grafika, Kód & Hijaz/AdLib Synth\n• Platformok: iOS 16+, iPadOS 16+, macOS 14+ Universal 2\n• Üzleti modell: Egyszeri vásárlás • Reklám- és IAP-mentes"
)

func renderPDF(_ copy: SheetCopy) {
    let mktURL = projectDir.appendingPathComponent("Marketing/\(copy.outName)")
    let distURL = projectDir.appendingPathComponent("dist/\(copy.outName)")

    let pageW: CGFloat = 595.28
    let pageH: CGFloat = 841.89
    var mediaBox = CGRect(x: 0, y: 0, width: pageW, height: pageH)

    guard let consumer = CGDataConsumer(url: mktURL as CFURL),
          let pdfCtx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

    let cs = CGColorSpaceCreateDeviceRGB()
    let gold    = NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.28, alpha: 1.0)
    let cyan    = NSColor(calibratedRed: 0.22, green: 0.91, blue: 1.00, alpha: 1.0)
    let crimson = NSColor(calibratedRed: 0.95, green: 0.34, blue: 0.38, alpha: 1.0)
    let emerald = NSColor(calibratedRed: 0.20, green: 0.92, blue: 0.56, alpha: 1.0)
    let cardBg  = NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.20, alpha: 0.95)
    let muted   = NSColor(calibratedRed: 0.85, green: 0.90, blue: 0.98, alpha: 1.0)

    pdfCtx.beginPDFPage(nil)

    let bgGrad = CGGradient(
        colorsSpace: cs,
        colors: [
            NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.13, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.22, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.14, alpha: 1).cgColor
        ] as CFArray,
        locations: [0.0, 0.52, 1.0]
    )!
    pdfCtx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: pageH), end: CGPoint(x: pageW, y: 0), options: [])

    let outerFrame = CGPath(roundedRect: CGRect(x: 16, y: 16, width: pageW - 32, height: pageH - 32), cornerWidth: 14, cornerHeight: 14, transform: nil)
    pdfCtx.setStrokeColor(gold.withAlphaComponent(0.45).cgColor)
    pdfCtx.setLineWidth(1.3)
    pdfCtx.addPath(outerFrame)
    pdfCtx.strokePath()

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: pdfCtx, flipped: false)

    func drawText(_ text: String, rect: CGRect, font: NSFont, color: NSColor, align: NSTextAlignment = .left, lineSpacing: CGFloat = 1.5) {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineSpacing = lineSpacing
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }

    func drawCard(_ rect: CGRect, border: NSColor, fill: NSColor = cardBg, radius: CGFloat = 10) {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        pdfCtx.setFillColor(fill.cgColor)
        pdfCtx.addPath(path)
        pdfCtx.fillPath()
        pdfCtx.setStrokeColor(border.withAlphaComponent(0.62).cgColor)
        pdfCtx.setLineWidth(1.15)
        pdfCtx.addPath(path)
        pdfCtx.strokePath()
    }

    func drawClippedImage(_ img: CGImage?, in rect: CGRect, radius: CGFloat = 8, border: NSColor? = nil) {
        guard let img = img else { return }
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        pdfCtx.saveGState()
        pdfCtx.addPath(path)
        pdfCtx.clip()
        pdfCtx.interpolationQuality = .high
        pdfCtx.draw(img, in: rect)
        pdfCtx.restoreGState()
        if let b = border {
            pdfCtx.setStrokeColor(b.cgColor)
            pdfCtx.setLineWidth(1.2)
            pdfCtx.addPath(path)
            pdfCtx.strokePath()
        }
    }

    let heroRect = CGRect(x: 28, y: pageH - 220, width: pageW - 56, height: 192)
    drawClippedImage(bannerImg, in: heroRect, radius: 12, border: gold.withAlphaComponent(0.88))

    let titleBarRect = CGRect(x: heroRect.minX + 8, y: heroRect.minY + 8, width: heroRect.width - 16, height: 64)
    let titleBarPath = CGPath(roundedRect: titleBarRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
    pdfCtx.setFillColor(NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.16, alpha: 0.88).cgColor)
    pdfCtx.addPath(titleBarPath)
    pdfCtx.fillPath()

    drawClippedImage(iconImg, in: CGRect(x: pageW - 102, y: heroRect.minY + 12, width: 56, height: 56), radius: 12, border: gold.withAlphaComponent(0.75))

    drawText("MIRAGE BLADE: HOURGLASS", rect: CGRect(x: 46, y: heroRect.minY + 36, width: 430, height: 26), font: .systemFont(ofSize: 19.5, weight: .black), color: gold)
    drawText(copy.subtitle, rect: CGRect(x: 46, y: heroRect.minY + 14, width: 435, height: 18), font: .systemFont(ofSize: 8.6, weight: .semibold), color: .white)

    let pillColors = [gold, cyan, crimson, emerald]
    let pillW = (pageW - 56 - 24) / 4.0
    let pillY: CGFloat = pageH - 248
    for i in 0..<4 {
        let px = 28 + CGFloat(i) * (pillW + 8)
        let pRect = CGRect(x: px, y: pillY, width: pillW, height: 20)
        drawCard(pRect, border: pillColors[i], fill: pillColors[i].withAlphaComponent(0.14), radius: 10)
        drawText(copy.pills[i], rect: CGRect(x: px, y: pillY - 1, width: pillW, height: 17), font: .systemFont(ofSize: 7.6, weight: .bold), color: pillColors[i], align: .center)
    }

    let colW: CGFloat = (pageW - 68) / 2.0
    let leftX: CGFloat = 28
    let rightX: CGFloat = 28 + colW + 12
    let midRowY: CGFloat = pageH - 408

    drawCard(CGRect(x: leftX, y: midRowY, width: colW, height: 150), border: gold)
    drawText(copy.leftTitle, rect: CGRect(x: leftX + 12, y: midRowY + 124, width: colW - 24, height: 16), font: .systemFont(ofSize: 9.8, weight: .heavy), color: gold)
    drawText(copy.leftBody, rect: CGRect(x: leftX + 12, y: midRowY + 6, width: colW - 24, height: 115), font: .systemFont(ofSize: 7.8, weight: .regular), color: muted, lineSpacing: 1.35)

    drawCard(CGRect(x: rightX, y: midRowY, width: colW, height: 150), border: cyan)
    drawText(copy.rightTitle, rect: CGRect(x: rightX + 12, y: midRowY + 124, width: colW - 24, height: 16), font: .systemFont(ofSize: 9.8, weight: .heavy), color: cyan)
    drawText(copy.rightBody, rect: CGRect(x: rightX + 12, y: midRowY + 6, width: colW - 24, height: 115), font: .systemFont(ofSize: 7.8, weight: .regular), color: muted, lineSpacing: 1.35)

    let secBoxY: CGFloat = pageH - 528
    drawCard(CGRect(x: 28, y: secBoxY, width: pageW - 56, height: 110), border: gold)
    drawText(copy.stripTitle, rect: CGRect(x: 40, y: secBoxY + 84, width: 515, height: 16), font: .systemFont(ofSize: 8.8, weight: .heavy), color: gold)

    let cardColors: [NSColor] = [cyan, gold, crimson, emerald, cyan, .white]
    let sCardW: CGFloat = (pageW - 80 - 25) / 6.0
    for (i, w) in copy.cards.enumerated() {
        let sx = 40 + CGFloat(i) * (sCardW + 5)
        let sRect = CGRect(x: sx, y: secBoxY + 10, width: sCardW, height: 70)
        drawCard(sRect, border: cardColors[i], fill: NSColor(calibratedRed: 0.04, green: 0.07, blue: 0.16, alpha: 0.96), radius: 7)
        drawText(w.0, rect: CGRect(x: sx + 5, y: secBoxY + 59, width: sCardW - 10, height: 13), font: .systemFont(ofSize: 6.7, weight: .black), color: cardColors[i])
        drawText(w.1, rect: CGRect(x: sx + 5, y: secBoxY + 23, width: sCardW - 10, height: 34), font: .systemFont(ofSize: 6.8, weight: .regular), color: muted, lineSpacing: 1.05)
        drawText(w.2, rect: CGRect(x: sx + 5, y: secBoxY + 9, width: sCardW - 10, height: 12), font: .monospacedSystemFont(ofSize: 6.6, weight: .bold), color: .white)
    }

    let galY: CGFloat = pageH - 666
    let shotW: CGFloat = (pageW - 56 - 16) / 3.0
    let shotH: CGFloat = shotW * (1600.0 / 2560.0)
    let shots: [(CGImage?, String, NSColor)] = [
        (shotDuel, copy.shotCaptions[0], gold),
        (shotViz,  copy.shotCaptions[1], cyan),
        (shotCat,  copy.shotCaptions[2], crimson)
    ]
    for (i, item) in shots.enumerated() {
        let gx = 28 + CGFloat(i) * (shotW + 8)
        let imgRect = CGRect(x: gx, y: galY + 18, width: shotW, height: shotH)
        drawClippedImage(item.0, in: imgRect, radius: 8, border: item.2)
        drawText(item.1, rect: CGRect(x: gx, y: galY + 1, width: shotW, height: 14), font: .systemFont(ofSize: 7.3, weight: .bold), color: item.2, align: .center)
    }

    let footY: CGFloat = 28
    let footH: CGFloat = galY - footY - 8
    drawCard(CGRect(x: 28, y: footY, width: pageW - 56, height: footH), border: emerald)

    drawText(copy.footLeftTitle, rect: CGRect(x: 42, y: footY + footH - 23, width: 255, height: 15), font: .systemFont(ofSize: 9.2, weight: .heavy), color: emerald)
    drawText(copy.footLeftBody, rect: CGRect(x: 42, y: footY + 8, width: 258, height: footH - 33), font: .systemFont(ofSize: 7.9, weight: .regular), color: muted, lineSpacing: 1.85)

    drawText(copy.footRightTitle, rect: CGRect(x: 312, y: footY + footH - 23, width: 248, height: 15), font: .systemFont(ofSize: 9.2, weight: .heavy), color: gold)
    drawText(copy.footRightBody, rect: CGRect(x: 312, y: footY + 8, width: 248, height: footH - 33), font: .systemFont(ofSize: 7.9, weight: .regular), color: muted, lineSpacing: 1.85)

    NSGraphicsContext.restoreGraphicsState()
    pdfCtx.endPDFPage()
    pdfCtx.closePDF()

    try? FileManager.default.removeItem(at: distURL)
    try? FileManager.default.copyItem(at: mktURL, to: distURL)
    print("Generated \(mktURL.path) & \(distURL.path)")
}

renderPDF(enCopy)
renderPDF(huCopy)
