#if os(iOS)
import UIKit
import SpriteKit

final class MirageBladeViewController: UIViewController {
    private let skView = SKView()
    private let touchOverlay = TouchControlsOverlay()
    private var sceneRef: GameScene?
    private var uiSyncLink: CADisplayLink?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        skView.frame = view.bounds
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 120
        view.addSubview(skView)

        let scene = GameScene(size: CGSize(width: 1280, height: 800))
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)
        self.sceneRef = scene

        touchOverlay.frame = view.bounds
        touchOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        touchOverlay.gameScene = scene
        view.addSubview(touchOverlay)

        let link = CADisplayLink(target: self, selector: #selector(syncOverlay))
        link.add(to: .main, forMode: .common)
        self.uiSyncLink = link
    }

    @objc private func syncOverlay() {
        touchOverlay.syncVisibilityWithScene()
    }

    override var prefersStatusBarHidden: Bool { true }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { [.bottom, .top] }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }
}

@main
final class MobileAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let win = UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = MirageBladeViewController()
        win.makeKeyAndVisible()
        self.window = win
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        AudioSynth.shared.setPaused(true)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AudioSynth.shared.setPaused(false)
    }
}
#endif
