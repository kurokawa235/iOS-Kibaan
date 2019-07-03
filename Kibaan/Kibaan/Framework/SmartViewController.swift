//
//  Created by 山本 敬太 on 2017/12/25.
//

import UIKit

/// 基盤ViewController
open class SmartViewController: UIViewController {
    
    /// 同クラスのインスタンスが複数存在する場合に識別するためのID
    open var viewID: String = ""
    /// 子のViewController
    private var subControllers = [SmartViewController]()
    /// 表示中の子ViewControllerの配列
    open var foregroundSubControllers: [SmartViewController] { return [] }
    /// 表示中のViewController
    open var foregroundController: SmartViewController { return nextScreens.last ?? self }
    /// 紐づくタスクのコンテナ
    open var taskHolder = TaskHolder()
    /// 上に乗せたオーバーレイ画面
    private var overlays = [SmartViewController]()
    /// オーバーレイ画面が乗っているか
    open var hasOverlay: Bool { return !overlays.isEmpty }
    /// スライド表示させた画面リスト
    private var nextScreens = [SmartViewController]()
    /// スライド表示させる画面を追加する対象のビュー
    open var nextScreenContainer: UIView? { return nil }
    /// スライドアニメーション時間
    open var nextScreenAnimationDuration: TimeInterval = 0.3
    /// スライドアニメーション中に表示するスキン
    private var nextScreenSkinView: UIView?
    /// スライドアニメーション中に表示するスキンの色
    private var nextScreenSkinColor: UIColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.2)
    /// 前画面に戻る為のEdgePanGesture
    var edgePanGesture: UIScreenEdgePanGestureRecognizer?
    /// ビューが隠れるときのスライド幅
    var slideWidthOnHide: CGFloat { return (nextScreenContainer?.frame.width ?? 0) / 4 }
    /// オーバーレイ画面のオーナー
    open weak var owner: SmartViewController?
    /// スライド表示させた画面の遷移のルート
    open weak var navigationRootController: SmartViewController?
    /// 画面表示中かどうか
    open var isForeground: Bool = false
    /// 画面遷移アニメーション
    open var transitionAnimation: TransitionAnimation?
    
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    // MARK: - Lifecycle
    
    open func commonInit() {
        // override by subclass
    }
    
    /// 画面を追加する
    public func added() {
        onAddedToScreen()
    }
    
    /// 画面表示を開始する
    public func enter() {
        foregroundController.onEnterForeground()
    }

    /// 画面表示を終了する
    public func leave() {
        foregroundController.onLeaveForeground()
    }
    
    /// 画面を取り除く
    public func removed() {
        onRemovedFromScreen()
        navigationRootController = nil
    }
    
    /// 画面がスクリーンに追加されたときの処理
    open func onAddedToScreen() {
        subControllers.forEach { $0.added() }
    }
    
    /// 画面がフォアグラウンド状態になったときの処理
    open func onEnterForeground() {
        isForeground = true
        enterForegroundSubControllers()
    }
    
    /// 画面がフォアグラウンド状態から離脱したときの処理
    open func onLeaveForeground() {
        taskHolder.clearAll()
        leaveForegroundSubControllers()
        isForeground = false
    }
    
    /// 画面がスクリーンから取り除かれたときの処理
    open func onRemovedFromScreen() {
        subControllers.forEach { $0.removed() }
    }
    
    /// 子ViewControllerを追加する
    open func addSubController(_ controller: SmartViewController) {
        controller.owner = self
        subControllers.append(controller)
    }
    
    /// 子ViewControllerを複数追加する
    open func addSubControllers(_ controllers: [SmartViewController]) {
        subControllers.forEach {
            $0.owner = self
        }
        subControllers.append(contentsOf: controllers)
    }
    
    // MARK: - Next screen
    
    /// スクロールビュー上でもEdgePanGestureを有効にする
    func enableEdgePanGesture(scrollView: UIScrollView) {
        guard let gesture = navigationRootController?.edgePanGesture else { return }
        scrollView.panGestureRecognizer.require(toFail: gesture)
    }
    
    /// ViewControllerをスライド表示させる
    @discardableResult
    open func addNextScreen<T: SmartViewController>(_ type: T.Type, id: String? = nil, cache: Bool = true, animated: Bool = true, prepare: ((T) -> Void)? = nil) -> T? {
        guard let parent = nextScreenContainer else {
            assertionFailure("""
                'nextScreenContainer' must be implemented if you call 'addNextScreen'.
                'nextScreenContainer' is container of screens. The screens transit inside 'nextScreenContainer'. Transition animation is clipped by 'nextScreenContainer'.
                If 'nextScreenContainer' has subviews from the beginning, the first call of 'addNextScreen' pushes out the subviews to outside of 'nextScreenContainer'.
            """)
            return nil
        }
        let controller = ViewControllerCache.shared.get(type, id: id, cache: cache)
        controller.navigationRootController = self
        
        let nextView: UIView = controller.view
        parent.addSubview(nextView)
        parent.clipsToBounds = true
        
        // 親にくっつける
        nextView.translatesAutoresizingMaskIntoConstraints = false
        nextView.topAnchor.constraint(equalTo: parent.topAnchor).isActive = true
        nextView.leadingAnchor.constraint(equalTo: parent.leadingAnchor).isActive = true
        nextView.bottomAnchor.constraint(equalTo: parent.bottomAnchor).isActive = true
        nextView.trailingAnchor.constraint(equalTo: parent.trailingAnchor).isActive = true
        
        leave()
        nextScreens += [controller]
        
        if animated {
            prepareForward(nextView: nextView)
            forwardAnimation(parent: parent, child: nextView, duration: nextScreenAnimationDuration)
        }
        if edgePanGesture == nil {
            let gesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(self.edgePanAction(gesture:)))
            gesture.edges = .left
            view.addGestureRecognizer(gesture)
            edgePanGesture = gesture
        }
        prepare?(controller)
        controller.added()
        controller.enter()
        return controller
    }
    
    /// スライド表示させたViewControllerを１つ前に戻す
    open func removeNextScreen(animated: Bool = true) {
        guard let parent = nextScreenContainer else { return }
        let lastScreen = nextScreens.removeLast()
        lastScreen.leave()
        
        enter()
        
        let completion = {
            lastScreen.view.removeFromSuperview()
            lastScreen.removed()
            self.clearEdgePanGesture()
        }
        
        if animated {
            prepareBack(nextView: lastScreen.view)
            backAnimation(parent: parent, child: lastScreen.view, duration: nextScreenAnimationDuration, completion: completion)
        } else {
            completion()
        }
    }
    
    private func removeNextScreenByGesture(parent: UIView, child: UIView, duration: TimeInterval) {
        guard let parent = nextScreenContainer else { return }
        let lastScreen = nextScreens.removeLast()
        lastScreen.leave()
        
        enter()
        
        backAnimation(parent: parent, child: lastScreen.view, duration: duration, completion: {
            lastScreen.view.removeFromSuperview()
            lastScreen.removed()
            self.clearEdgePanGesture()
        })
    }
    
    /// スライド表示させたViewControllerを全て閉じる
    open func removeAllNextScreen(executeStart: Bool = false) {
        guard isViewLoaded else { return }
        leave()
        nextScreens.forEach {
            $0.view.removeFromSuperview()
            $0.removed()
        }
        nextScreens.removeAll()
        if executeStart {
            enter()
        }
    }
    
    @objc func edgePanAction(gesture: UIScreenEdgePanGestureRecognizer) {
        guard nextScreenContainer?.isUserInteractionEnabled == true else { return }
        guard let nextScreenFrame = nextScreenContainer, let frontView = nextScreens.last?.view, 0 < nextScreens.count else { return }
        let rootView = nextScreenFrame
        let translation = gesture.translation(in: frontView)
        let percentage = translation.x / frontView.frame.width
        
        if gesture.state == .began {
            showSkinView(frontView: frontView, alpha: 1.0)
        }
        if 0 < translation.x {
            let rootViewX = slideWidthOnHide * (percentage - 1)
            rootView.subviews.transform(transform: CGAffineTransform(translationX: rootViewX, y: 0))
            frontView.transform = CGAffineTransform(translationX: translation.x, y: 0)
            frontView.layer.shadowOpacity = Float(1.0 - percentage)
            nextScreenSkinView?.alpha = 1.0 - percentage
        }
        if frontView.transform != .identity && (gesture.state == .ended || gesture.state == .cancelled) {
            let velocity = gesture.velocity(in: frontView)
            if (frontView.frame.width / 2) < translation.x || 1000.0 < velocity.x {
                let duration = TimeInterval(CGFloat(nextScreenAnimationDuration) * (1.0 - percentage))
                removeNextScreenByGesture(parent: rootView, child: frontView, duration: duration)
            } else {
                let duration = TimeInterval(CGFloat(nextScreenAnimationDuration) * percentage)
                forwardAnimation(parent: rootView, child: frontView, duration: duration)
            }
        }
    }
    
    private func prepareBack(nextView: UIView) {
        // スキンを表示する
        showSkinView(frontView: nextView, alpha: 1.0)
        // 影を表示する
        nextView.layer.shadowOpacity = 1.0
        // ビューの初期位置を調整
        nextScreenContainer?.subviews.filter { $0 != nextView }.transform(transform: CGAffineTransform(translationX: -slideWidthOnHide, y: 0))
    }
    
    private func prepareForward(nextView: UIView) {
        // スキンを表示する
        showSkinView(frontView: nextView, alpha: 0.0)
        // 影をつける
        setShadow(targetView: nextView, percentage: 0.0)
        // ビューの初期位置を調整
        nextView.transform = CGAffineTransform(translationX: nextView.frame.width, y: 0)
    }
    
    private func forwardAnimation(parent: UIView, child: UIView, duration: TimeInterval) {
        parent.isUserInteractionEnabled = false
        child.isUserInteractionEnabled = false
        
        UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseOut], animations: {
            parent.subviews.transform(transform: CGAffineTransform(translationX: -self.slideWidthOnHide, y: 0))
            child.transform = .identity
            self.nextScreenSkinView?.alpha = 1.0
        }, completion: { _ in
            parent.subviews.transform(transform: .identity)
            parent.isUserInteractionEnabled = true
            child.isUserInteractionEnabled = true
            self.hideSkinView()
        })
        setShadowOpacityAnimation(view: child, toValue: 1.0, duration: duration, completion: {
            child.layer.shadowOpacity = 0.0
        })
    }
    
    private func backAnimation(parent: UIView, child: UIView, duration: TimeInterval, completion: (() -> Void)? = nil) {
        parent.isUserInteractionEnabled = false
        child.isUserInteractionEnabled = false
        
        UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseOut], animations: {
            parent.subviews.transform(transform: .identity)
            child.transform = CGAffineTransform(translationX: child.frame.width, y: 0)
            self.nextScreenSkinView?.alpha = 0.0
        }, completion: { result in
            child.transform = .identity
            child.isUserInteractionEnabled = true
            parent.isUserInteractionEnabled = true
            self.hideSkinView()
            completion?()
        })
        setShadowOpacityAnimation(view: child, toValue: 0.0, duration: duration, completion: {
            child.layer.shadowOpacity = 0.0
        })
    }
    
    private func clearEdgePanGesture() {
        if let gesture = edgePanGesture, nextScreens.isEmpty {
            nextScreenContainer?.removeGestureRecognizer(gesture)
            edgePanGesture = nil
        }
    }
    
    private func showSkinView(frontView: UIView, alpha: CGFloat) {
        guard let parent = nextScreenContainer else { return }
        if nextScreenSkinView == nil {
            let skinView = UIView(frame: .zero)
            skinView.backgroundColor = nextScreenSkinColor
            skinView.alpha = alpha
            parent.addSubview(skinView)
            skinView.translatesAutoresizingMaskIntoConstraints = false
            skinView.topAnchor.constraint(equalTo: parent.topAnchor).isActive = true
            skinView.leadingAnchor.constraint(equalTo: parent.leadingAnchor).isActive = true
            skinView.bottomAnchor.constraint(equalTo: parent.bottomAnchor).isActive = true
            skinView.trailingAnchor.constraint(equalTo: parent.trailingAnchor).isActive = true
            parent.bringSubviewToFront(frontView)
            nextScreenSkinView = skinView
        }
    }
    
    private func hideSkinView() {
        nextScreenSkinView?.removeFromSuperview()
        nextScreenSkinView = nil
    }
    
    private func setShadow(targetView: UIView, percentage: Float = 1.0) {
        targetView.layer.shadowOffset = CGSize(width: 6.0, height: 0.0)
        targetView.layer.shadowColor = UIColor.black.cgColor
        targetView.layer.shadowOpacity = percentage
        targetView.layer.shadowRadius = 10
    }
    
    private func setShadowOpacityAnimation(view: UIView, fromValue: Float? = nil, toValue: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            completion?()
        }
        let animation = CABasicAnimation(keyPath: "shadowOpacity")
        animation.fromValue = fromValue ?? view.layer.shadowOpacity
        animation.duration = duration
        animation.toValue = toValue
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        view.layer.add(animation, forKey: "shadowOpacity")
        view.layer.shadowOpacity = toValue
        
        CATransaction.commit()
    }
    
    // MARK: - Overlay
    
    /// ViewControllerを上に乗せる
    @discardableResult
    open func addOverlay<T: SmartViewController>(_ type: T.Type, id: String? = nil, cache: Bool = true, prepare: ((T) -> Void)? = nil) -> T? {
        let controller = ViewControllerCache.shared.get(type, id: id, cache: cache)
        controller.owner = self
        overlays += [controller]
        
        view.addSubview(controller.view)
        AutoLayoutUtils.fit(controller.view, superView: self.view)
        
        prepare?(controller)
        controller.added()
        controller.enter()
        return controller
    }
    
    /// 上に乗ったViewControllerを外す
    open func removeOverlay<T: SmartViewController>(_ target: T.Type? = nil) {
        if 0 < overlays.count {
            var removed: SmartViewController?
            if let target = target {
                if let index = overlays.firstIndex(where: { type(of: $0) == target }) {
                    removed = overlays.remove(at: index)
                }
            } else {
                removed = overlays.removeLast()
            }
            
            removed?.owner = nil
            removed?.view.removeFromSuperview()
            removed?.leave()
            removed?.removed()
        }
    }
    
    /// 上に乗ったViewControllerを全て外す
    open func removeAllOverlay() {
        let allOverlays = Array(overlays)
        allOverlays.reversed().forEach {
            $0.owner = nil
            $0.view.removeFromSuperview()
            $0.leave()
            $0.removed()
            self.overlays.remove(element: $0)
        }
    }
    
    // MARK: - Other
    
    open func enterForegroundSubControllers() {
        if isForeground {
            foregroundSubControllers.forEach {
                $0.enter()
            }
        }
    }
    
    open func leaveForegroundSubControllers() {
        if isForeground {
            foregroundSubControllers.forEach {
                $0.leave()
            }
        }
    }
}

fileprivate extension Array where Element == UIView {
    func transform(transform: CGAffineTransform) {
        forEach {
            $0.transform = transform
        }
    }
}
