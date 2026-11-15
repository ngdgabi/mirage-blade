#if os(iOS)
import UIKit
import SpriteKit

@MainActor
final class TouchControlsOverlay: UIView {
    weak var gameScene: GameScene?

    private let stickBase = UIView()
    private let stickKnob = UIView()
    private let actionBtn = UIButton(type: .system)
    private let altBtn = UIButton(type: .system)
    private let pausePill = UIButton(type: .system)
    private let eraPill = UIButton(type: .system)
    private let chipPill = UIButton(type: .system)

    private var activeStickTouch: UITouch?
    private var stickOrigin: CGPoint = .zero
    private let stickRadius: CGFloat = 54

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        stickBase.backgroundColor = UIColor(white: 0.08, alpha: 0.44)
        stickBase.layer.borderColor = UIColor(red: 0.96, green: 0.77, blue: 0.27, alpha: 0.72).cgColor
        stickBase.layer.borderWidth = 2.0
        stickBase.layer.cornerRadius = stickRadius
        stickBase.isUserInteractionEnabled = false
        addSubview(stickBase)

        stickKnob.backgroundColor = UIColor(red: 0.96, green: 0.77, blue: 0.27, alpha: 0.85)
        stickKnob.layer.cornerRadius = 22
        stickKnob.isUserInteractionEnabled = false
        addSubview(stickKnob)

        configureArcadeButton(actionBtn, title: "SLASH", bg: UIColor(red: 0.89, green: 0.22, blue: 0.27, alpha: 0.80))
        actionBtn.addTarget(self, action: #selector(onActionDown), for: .touchDown)
        actionBtn.addTarget(self, action: #selector(onActionUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        addSubview(actionBtn)

        configureArcadeButton(altBtn, title: "LEAP", bg: UIColor(red: 0.14, green: 0.56, blue: 0.88, alpha: 0.80))
        altBtn.addTarget(self, action: #selector(onAltDown), for: .touchDown)
        altBtn.addTarget(self, action: #selector(onAltUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        addSubview(altBtn)

        configureTopPill(pausePill, title: "PAUSE")
        pausePill.addTarget(self, action: #selector(onPause), for: .touchUpInside)
        addSubview(pausePill)

        configureTopPill(eraPill, title: "ERA")
        eraPill.addTarget(self, action: #selector(onEra), for: .touchUpInside)
        addSubview(eraPill)

        configureTopPill(chipPill, title: "CHIP")
        chipPill.addTarget(self, action: #selector(onChip), for: .touchUpInside)
        addSubview(chipPill)
    }

    private func configureArcadeButton(_ btn: UIButton, title: String, bg: UIColor) {
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        btn.backgroundColor = bg
        btn.layer.borderColor = UIColor(red: 0.96, green: 0.77, blue: 0.27, alpha: 0.88).cgColor
        btn.layer.borderWidth = 2.0
    }

    private func configureTopPill(_ btn: UIButton, title: String) {
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(UIColor(red: 0.96, green: 0.77, blue: 0.27, alpha: 1.0), for: .normal)
        btn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        btn.backgroundColor = UIColor(red: 0.05, green: 0.08, blue: 0.18, alpha: 0.82)
        btn.layer.borderColor = UIColor(red: 0.96, green: 0.77, blue: 0.27, alpha: 0.68).cgColor
        btn.layer.borderWidth = 1.5
        btn.layer.cornerRadius = 14
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let safe = safeAreaInsets
        let w = bounds.width
        let h = bounds.height

        let cx = max(92, safe.left + 74)
        let cy = h - max(88, safe.bottom + 76)
        stickOrigin = CGPoint(x: cx, y: cy)
        stickBase.frame = CGRect(x: cx - stickRadius, y: cy - stickRadius, width: stickRadius * 2, height: stickRadius * 2)
        if activeStickTouch == nil {
            stickKnob.frame = CGRect(x: cx - 22, y: cy - 22, width: 44, height: 44)
        }

        let btnSize: CGFloat = 76
        actionBtn.frame = CGRect(x: w - max(98, safe.right + 88), y: h - max(98, safe.bottom + 88), width: btnSize, height: btnSize)
        actionBtn.layer.cornerRadius = btnSize * 0.5

        let altSize: CGFloat = 68
        altBtn.frame = CGRect(x: actionBtn.frame.minX - altSize - 18, y: actionBtn.frame.minY + 12, width: altSize, height: altSize)
        altBtn.layer.cornerRadius = altSize * 0.5

        let topY = max(12, safe.top + 8)
        pausePill.frame = CGRect(x: max(16, safe.left + 14), y: topY, width: 72, height: 28)
        chipPill.frame = CGRect(x: w - max(16, safe.right + 14) - 68, y: topY, width: 68, height: 28)
        eraPill.frame = CGRect(x: chipPill.frame.minX - 74, y: topY, width: 68, height: 28)
    }

    func syncVisibilityWithScene() {
        guard let sc = gameScene else { return }
        let showArcade = sc.isActionArcadePhase
        stickBase.isHidden = !showArcade
        stickKnob.isHidden = !showArcade
        actionBtn.isHidden = !showArcade
        altBtn.isHidden = !showArcade

        let showTop = (sc.mode == .dungeonPlay || sc.mode == .duelArena)
        pausePill.isHidden = !showTop
        eraPill.isHidden = !showTop
        chipPill.isHidden = !showTop
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for sub in [actionBtn, altBtn, pausePill, eraPill, chipPill] where !sub.isHidden {
            let p = sub.convert(point, from: self)
            if sub.bounds.insetBy(dx: -8, dy: -8).contains(p) {
                return sub
            }
        }
        if !stickBase.isHidden && point.x < bounds.width * 0.36 && point.y > bounds.height * 0.42 {
            return self
        }
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeStickTouch == nil, let t = touches.first else { return }
        activeStickTouch = t
        updateStick(with: t.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active = activeStickTouch, touches.contains(active) else { return }
        updateStick(with: active.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let active = activeStickTouch, touches.contains(active) {
            resetStick()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let active = activeStickTouch, touches.contains(active) {
            resetStick()
        }
    }

    private func updateStick(with pt: CGPoint) {
        let dx = pt.x - stickOrigin.x
        let dy = pt.y - stickOrigin.y
        let dist = hypot(dx, dy)
        let clamped = min(stickRadius, dist)
        let angle = atan2(dy, dx)
        stickKnob.center = CGPoint(x: stickOrigin.x + cos(angle) * clamped, y: stickOrigin.y + sin(angle) * clamped)

        TouchInputState.shared.moveDX = (clamped > 8) ? (cos(angle) * (clamped / stickRadius)) : 0
        TouchInputState.shared.moveDY = (clamped > 8) ? (-sin(angle) * (clamped / stickRadius)) : 0
    }

    private func resetStick() {
        activeStickTouch = nil
        stickKnob.center = stickOrigin
        TouchInputState.shared.moveDX = 0
        TouchInputState.shared.moveDY = 0
    }

    @objc private func onActionDown() {
        TouchInputState.shared.primaryHeld = true
        TouchInputState.shared.primaryJustPressed = true
        HapticsManager.lightImpact()
    }

    @objc private func onActionUp() {
        TouchInputState.shared.primaryHeld = false
    }

    @objc private func onAltDown() {
        TouchInputState.shared.secondaryHeld = true
        TouchInputState.shared.secondaryJustPressed = true
        HapticsManager.tap()
    }

    @objc private func onAltUp() {
        TouchInputState.shared.secondaryHeld = false
    }

    @objc private func onPause() { gameScene?.togglePauseFromUI() }
    @objc private func onEra()   { gameScene?.cycleVisualTheme() }
    @objc private func onChip()  { gameScene?.cycleAudioChip() }
}
#endif
