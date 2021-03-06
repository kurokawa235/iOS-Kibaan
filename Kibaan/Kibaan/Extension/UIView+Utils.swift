import UIKit

public extension UIView {
    
    // MARK: - Computed Property

    /// SafeAreaの余白サイズ
    /// iOS11未満はサイズゼロの余白を返却する
    var safeAreaInsetsOrZero: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return safeAreaInsets
        }
        return UIEdgeInsets.zero
    }
    
    /// 親ビューからこのビューに設定された制約
    var parentConstraints: [NSLayoutConstraint] {
        guard let superview = superview else { return [] }
        return superview.constraints.filter {
            $0.firstItem === self || $0.secondItem === self
        }
    }
    
    /// - Attention: 親がUIStackViewの場合にのみ使用すること
    /// - Remark: "isHidden"と全く同じ挙動だがAndroid版移植時の効率化のために本プロパティを追加している
    var isGone: Bool {
        get { return isHidden }
        set(value) { isHidden = value }
    }
    
    // MARK: - Function
    
    /// 角丸を設定する
    ///
    /// - precondition: viewDidLoadなどViewのサイズ(bounds)が定まっていないタイミングでは呼ばないこと
    func setCornerRadius(corners: UIRectCorner, radius: CGFloat = 4) {
        let maskPath = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let maskLayer = CAShapeLayer()
        maskLayer.frame = self.bounds
        maskLayer.path = maskPath.cgPath
        self.layer.mask = maskLayer
    }
    
    /// 角丸半径
    @IBInspectable var cornerRadius: CGFloat {
        get { return layer.cornerRadius }
        set(value) {
            layer.cornerRadius = value
        }
    }
    
    /// 枠線の色
    @IBInspectable var borderColor: UIColor? {
        get {
            if let cgColor = layer.borderColor {
                return UIColor(cgColor: cgColor)
            }
            return nil
        }
        set(value) {
            layer.borderColor = value?.cgColor
        }
    }
    
    /// 枠線の太さ
    @IBInspectable var borderWidth: CGFloat {
        get { return layer.borderWidth }
        set(value) {
            layer.borderWidth = value
        }
    }
    
    /// ドロップシャドウの色
    @IBInspectable
    var shadowColor: UIColor? {
        get {
            if let color = layer.shadowColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.shadowColor = color.cgColor
            } else {
                layer.shadowColor = nil
            }
        }
    }

    /// ドロップシャドウのオフセット
    @IBInspectable
    var shadowOffset: CGSize {
        get { return layer.shadowOffset }
        set { layer.shadowOffset = newValue }
    }
    
    /// ドロップシャドウの不透明（1が完全に不透明、0が完全に透明）
    @IBInspectable
    var shadowOpacity: Float {
        get { return layer.shadowOpacity }
        set { layer.shadowOpacity = newValue }
    }

    /// ドロップシャドウの半径
    @IBInspectable
    var shadowRadius: CGFloat {
        get { return layer.shadowRadius }
        set { layer.shadowRadius = newValue }
    }
    
    // MARK: - Function
    
    /// グラデーションを設定する
    func setGradient(_ colors: [UIColor], startPoint: CGPoint, endPoint: CGPoint) {
        let cgColors = colors.map { $0.cgColor }
        
        let gradientLayer: CAGradientLayer = CAGradientLayer()
        gradientLayer.colors = cgColors
        gradientLayer.frame = bounds
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        
        removeGradient()
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    /// グラデーションを削除する
    func removeGradient() {
        layer.sublayers?.filter { $0 as? CAGradientLayer != nil }.forEach {
            $0.removeFromSuperlayer()
        }
    }

    /// 画像を作成する
    func createImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
