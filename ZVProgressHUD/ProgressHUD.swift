//
//  ProgressHUD.swift
//  ProgressHUD
//
//  Created by zevwings on 2017/7/12.
//  Copyright © 2017-2019 zevwings. All rights reserved.
//

import UIKit

public typealias ProgressHUDCompletionHandler = () -> ()

public extension Notification.Name {
    
    static let ProgressHUDReceivedTouchUpInsideEvent = Notification.Name("com.zevwings.progresshud.touchup.inside")
    
    static let ProgressHUDWillAppear = Notification.Name("com.zevwings.progresshud.willAppear")
    static let ProgressHUDDidAppear = Notification.Name("com.zevwings.progresshud.didAppear")
    
    static let ProgressHUDWillDisappear = Notification.Name("com.zevwings.progresshud.willDisappear")
    static let ProgressHUDDidDisappear = Notification.Name("com.zevwings.progresshud.didDisappear")
}

open class ProgressHUD: UIControl {
    
    private struct AnimationDuration {
        static let fadeIn: TimeInterval = 0.15
        static let fadeOut: TimeInterval = 0.15
        static let keyboard: TimeInterval = 0.25
    }
    
    public enum DisplayType {
        case indicator(title: String?, type: IndicatorView.IndicatorType)
        case text(value: String)
    }
    
    public enum DisplayStyle {
        case light
        case dark
        case custom(backgroundColor: UIColor, foregroundColor: UIColor)
    }
    
    public enum MaskType {
        case none
        case clear
        case black
        case custom(color: UIColor)
    }
    
    public enum Position {
        case top
        case center
        case bottom
    }

    //MARK: Public
    
    public static let shared = ProgressHUD(frame: .zero)
    
    public var displayStyle: DisplayStyle = .light
    public var maskType: MaskType = .none
    public var position:Position = .center
    
    public var maxSupportedWindowLevel: UIWindow.Level = .normal
    public var fadeInAnimationTimeInterval: TimeInterval = AnimationDuration.fadeIn
    public var fadeOutAnimationTImeInterval: TimeInterval = AnimationDuration.fadeOut
    
    public var minimumDismissTimeInterval: TimeInterval = 3.0
    public var maximumDismissTimeInterval: TimeInterval = 10.0
    
    public var cornerRadius: CGFloat = 8.0
    public var offset: UIOffset = .zero
    
    public var font: UIFont = .systemFont(ofSize: 16.0)
    
    public var strokeWith: CGFloat = 3.0
    public var indicatorSize: CGSize = .init(width: 48.0, height: 48.0)
    public var logoSize: CGSize = .init(width: 30.0, height: 30.0)
    public var animationType: IndicatorView.AnimationType = .flat

    public var contentInsets: UIEdgeInsets = .init(top: 12.0, left: 12.0, bottom: 12.0, right: 12.0)
    public var titleEdgeInsets: UIEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 0 )
    public var indicatorEdgeInsets: UIEdgeInsets = .init(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)

    public var logo: UIImage?
    public var completionHandler: ProgressHUDCompletionHandler?
    
    // MARK: Private
    
    private var _fadeOutTimer: Timer?
    private var _fadeInDeleyTimer: Timer?
    private var _fadeOutDelayTimer: Timer?

    
    private var displayType: DisplayType?
    
    private var containerView: UIView?

    private lazy var maskLayer: CALayer = { [unowned self] in
        let maskLayer = CALayer()
        return maskLayer
    }()
    
    private lazy var baseView: UIControl = {
        let baseView = UIControl()
        baseView.backgroundColor = .clear
        baseView.alpha = 0
        baseView.layer.masksToBounds = true
        return baseView
    }()
    
    private lazy var indicatorView: IndicatorView = {
        let indicatorView = IndicatorView()
        indicatorView.isUserInteractionEnabled = false
        indicatorView.alpha = 0
        return indicatorView
    }()
    
    private lazy var titleLabel: UILabel = { [unowned self] in
        
        let titleLabel = UILabel(frame: .zero)
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false
        titleLabel.font = self.font
        titleLabel.backgroundColor = .clear
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.numberOfLines = 0
        titleLabel.alpha = 0
        return titleLabel
    }()
    
    private lazy var logoView: UIImageView = { [unowned self] in
        
        let logoView = UIImageView(frame: .zero)
        logoView.tintColor = self.displayStyle.foregroundColor
        logoView.contentMode = .scaleAspectFit
        logoView.layer.masksToBounds = true
        return logoView
    }()
    
    // MARK: Init
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        alpha = 0
        backgroundColor = .clear
        
        addTarget(self, action: #selector(overlayRecievedTouchUpInsideEvent(_:)), for: .touchUpInside)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    //MARK: Internal Operations

    func internalShow(with displayType: DisplayType,
                      in superview: UIView? = nil,
                      on position: Position,
                      delay delayTimeInterval: TimeInterval = 0) {
        
        OperationQueue.main.addOperation { [weak self] in
            
            guard let strongSelf = self else { return }

            if strongSelf.superview != superview {
                strongSelf.indicatorView.removeFromSuperview()
                strongSelf.titleLabel.removeFromSuperview()
                strongSelf.baseView.removeFromSuperview()
                strongSelf.logoView.removeFromSuperview()
                strongSelf.removeFromSuperview()
            }
            
            strongSelf.fadeOutTimer = nil
            strongSelf.fadeInDeleyTimer = nil
            strongSelf.fadeOutDelayTimer = nil
            
            strongSelf.position = position

            if let sv = superview {
                strongSelf.containerView = sv
            } else {
                strongSelf.containerView = strongSelf.keyWindow
            }
            
            // set property form displayType
            strongSelf.displayType = displayType
            strongSelf.titleLabel.text = displayType.title
            strongSelf.titleLabel.isHidden = displayType.title.isEmpty
            strongSelf.indicatorView.indcatorType = displayType.indicatorType
            
            strongSelf.updateViewHierarchy()

            strongSelf.titleLabel.font = strongSelf.font
            strongSelf.indicatorView.strokeWidth = strongSelf.strokeWith
            strongSelf.baseView.layer.cornerRadius = strongSelf.cornerRadius
            strongSelf.baseView.backgroundColor = strongSelf.displayStyle.backgroundColor
            strongSelf.logoView.image = strongSelf.logo
            
            // set property form maskType
            strongSelf.isUserInteractionEnabled = strongSelf.maskType.isUserInteractionEnabled
            strongSelf.maskLayer.backgroundColor = strongSelf.maskType.backgroundColor
            
            // set property form displayStyle
            strongSelf.titleLabel.textColor = strongSelf.displayStyle.foregroundColor
            strongSelf.indicatorView.tintColor = strongSelf.displayStyle.foregroundColor
            
            
            // display
            if delayTimeInterval > 0 {
                strongSelf.fadeInDeleyTimer = Timer.scheduledTimer(timeInterval: delayTimeInterval, target: strongSelf, selector: #selector(strongSelf.fadeInTimerAction(_:)), userInfo: nil, repeats: false)
            } else {
                strongSelf.fadeIn()
            }
        }
    }

    func internalDismiss(with delayTimeInterval: TimeInterval = 0, completion: ProgressHUDCompletionHandler? = nil) {
        
        if delayTimeInterval > 0 {
            fadeOutDelayTimer = Timer.scheduledTimer(timeInterval: delayTimeInterval, target: self, selector: #selector(fadeInTimerAction(_:)), userInfo: completion, repeats: false)
        } else {
            fadeOut(with: completion)
        }
    }
    
    @objc private func fadeInTimerAction(_ timer: Timer?) {
        fadeIn()
    }
    
    @objc private func fadeIn() {
        
        guard let displayType = displayType else { return }
        
        let displayTimeInterval = getDisplayTimeInterval(for: displayType)
        
        updateSubviews()
        placeSubviews()
        
        if self.alpha != 1.0 {
            
            // send the notification HUD will appear
            NotificationCenter.default.post(name: .ProgressHUDWillAppear, object: self, userInfo: nil)
            
            let animationBlock = {
                self.alpha = 1.0
                self.baseView.alpha = 1.0
                self.indicatorView.alpha = 1.0
                self.titleLabel.alpha = 1.0
            }
            
            let completionBlock = {
                
                guard self.alpha == 1.0 else { return }
                
                self.fadeInDeleyTimer = nil
                
                // register keyboard notification and orientation notification
                self.registerNotifications()
                
                // send the notification HUD did appear
                NotificationCenter.default.post(name: .ProgressHUDDidAppear, object: self, userInfo: nil)
                
                if displayTimeInterval > 0 {
                    self.fadeOutTimer = Timer.scheduledTimer(timeInterval: displayTimeInterval, target: self, selector: #selector(self.fadeOutTimerAction(_:)), userInfo: nil, repeats: false)
                    RunLoop.main.add(self.fadeOutTimer!, forMode: RunLoop.Mode.common)
                } else {
                    if displayType.indicatorType.progressValueChecker.0 &&
                        displayType.indicatorType.progressValueChecker.1 >= 1.0 {
                        self.dismiss()
                    }
                }
            }
            
            if fadeInAnimationTimeInterval > 0 {
                UIView.animate(withDuration: fadeInAnimationTimeInterval,
                               delay: 0,
                               options: [.allowUserInteraction, .curveEaseOut, .beginFromCurrentState],
                               animations: {
                                animationBlock()
                }, completion: { _ in
                    completionBlock()
                })
            } else {
                animationBlock()
                completionBlock()
            }
        } else {
            
            if displayTimeInterval > 0 {
                fadeOutTimer = Timer.scheduledTimer(timeInterval: displayTimeInterval, target: self, selector: #selector(self.fadeOutTimerAction(_:)), userInfo: nil, repeats: false)
                RunLoop.main.add(fadeOutTimer!, forMode: RunLoop.Mode.common)
            } else {
                if displayType.indicatorType.progressValueChecker.0 &&
                    displayType.indicatorType.progressValueChecker.1 >= 1.0 {
                    dismiss()
                }
            }
        }
    }

    @objc private func fadeOutTimerAction(_ timer: Timer?) {
        dismiss()
    }

    @objc private func fadeOut(with data: Any?) {
        
        var completion: ProgressHUDCompletionHandler?
        if let timer = data as? Timer {
            completion = timer.userInfo as? ProgressHUDCompletionHandler
        } else {
            completion = data as? ProgressHUDCompletionHandler
        }
        
        OperationQueue.main.addOperation { [weak self] in
            
            guard let strongSelf = self else { return }
            
            // send the notification HUD will disAppear
            NotificationCenter.default.post(name: .ProgressHUDWillDisappear, object: self, userInfo: nil)
            
            let animationBlock = {
                strongSelf.alpha = 0
                strongSelf.baseView.alpha = 0
                strongSelf.baseView.backgroundColor = .clear
                strongSelf.indicatorView.alpha = 0
                strongSelf.titleLabel.alpha = 0
            }
            
            let completionBlock = {
                
                guard strongSelf.alpha == 0 else { return }
                
                strongSelf.fadeOutTimer = nil
                strongSelf.fadeOutDelayTimer = nil
                
                // update view hierarchy
                strongSelf.indicatorView.removeFromSuperview()
                strongSelf.titleLabel.removeFromSuperview()
                strongSelf.baseView.removeFromSuperview()
                strongSelf.logoView.removeFromSuperview()
                strongSelf.removeFromSuperview()
                
                strongSelf.containerView = nil
                
                // remove notifications from self
                NotificationCenter.default.removeObserver(strongSelf)
                
                // send the notification HUD did disAppear
                NotificationCenter.default.post(name: .ProgressHUDDidDisappear, object: self, userInfo: nil)
                
                // execute completion handler
                completion?()
                strongSelf.completionHandler?()
            }
            
            if strongSelf.fadeOutAnimationTImeInterval > 0 {
                UIView.animate(withDuration: strongSelf.fadeOutAnimationTImeInterval,
                               delay: 0,
                               options: [.allowUserInteraction, .curveEaseOut, .beginFromCurrentState],
                               animations: {
                                animationBlock()
                }, completion: { _ in
                    completionBlock()
                })
            } else {
                animationBlock()
                completionBlock()
            }
            
            strongSelf.setNeedsDisplay()
        }
    }
    
    private func getDisplayTimeInterval(for displayType: DisplayType) -> TimeInterval {
        
        var displayTimeInterval: TimeInterval = displayType.dismissAtomically ? 3.0 : 0
        
        guard displayTimeInterval > 0 else { return 0 }
        
        displayTimeInterval = max(Double(displayType.title.count) * 0.06 + 0.5, minimumDismissTimeInterval)
        displayTimeInterval = min(displayTimeInterval, maximumDismissTimeInterval)
        
        return displayTimeInterval
    }

    private func registerNotifications() {
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(placeSubviews(_:)),
                                               name: UIApplication.didChangeStatusBarOrientationNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(placeSubviews(_:)),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(placeSubviews(_:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(placeSubviews(_:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(placeSubviews(_:)),
                                               name: UIResponder.keyboardDidShowNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(placeSubviews(_:)),
                                               name: UIResponder.keyboardDidHideNotification,
                                               object: nil)
    }
    
    private func updateViewHierarchy() {
        
        if superview == nil {
            containerView?.addSubview(self)
        } else {
            containerView?.bringSubviewToFront(self)
        }
        
        if maskLayer.superlayer == nil {
            layer.addSublayer(maskLayer)
        }
        
        if baseView.superview == nil {
            addSubview(baseView)
        } else {
            bringSubviewToFront(baseView)
        }
        
        if let displayType = displayType, displayType.indicatorType.showLogo, logo != nil, logoView.superview == nil {
            baseView.addSubview(logoView)
        } else {
            baseView.bringSubviewToFront(logoView)
        }
        
        if indicatorView.superview == nil {
            baseView.addSubview(indicatorView)
        } else {
            baseView.bringSubviewToFront(indicatorView)
        }
        
        if titleLabel.superview == nil {
            baseView.addSubview(titleLabel)
        } else {
            baseView.bringSubviewToFront(titleLabel)
        }
    }
    
    private func updateSubviews() {
        
        guard let containerView = containerView else { return }
        
        frame = .init(origin: .zero, size: containerView.frame.size)
        maskLayer.frame = .init(origin: .zero, size: containerView.frame.size)
        
        if !indicatorView.isHidden {
            indicatorView.frame = CGRect(origin: .zero, size: indicatorSize)
        }
        
        if let displayType = displayType, displayType.indicatorType.showLogo, logo != nil {
            logoView.frame = CGRect(origin: .zero, size: logoSize)
        }
        
        var labelSize: CGSize = .zero
        if !titleLabel.isHidden, let title = titleLabel.text as NSString?, title.length > 0 {
            let maxSize: CGSize = .init(width: frame.width * 0.618, height: frame.width * 0.618)
            let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: font]
            let options: NSStringDrawingOptions = [.usesFontLeading, .truncatesLastVisibleLine, .usesLineFragmentOrigin]
            labelSize = title.boundingRect(with: maxSize, options: options, attributes: attributes, context: nil).size
            titleLabel.frame = CGRect(origin: .zero, size: labelSize)
        }
        
        let labelHeight = titleLabel.isHidden ? 0 : labelSize.height + titleEdgeInsets.top + titleEdgeInsets.bottom
        let indicatorHeight = indicatorView.isHidden ? 0 : indicatorSize.height + indicatorEdgeInsets.top + indicatorEdgeInsets.bottom
        
        let contentHeight = labelHeight + indicatorHeight + contentInsets.top + contentInsets.bottom
        let contetnWidth = max(labelSize.width + titleEdgeInsets.left + titleEdgeInsets.right, indicatorSize.width + indicatorEdgeInsets.left + indicatorEdgeInsets.right) + contentInsets.left + contentInsets.right
        
        let contentSize: CGSize = .init(width: contetnWidth, height: contentHeight)
        let oldOrigin = self.baseView.frame.origin
        baseView.frame = .init(origin: oldOrigin, size: contentSize)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let centerX: CGFloat = contetnWidth / 2.0
        var centerY: CGFloat = contentHeight / 2.0

        // Indicator
        if labelHeight > 0 && !indicatorView.isHidden {
            centerY = contentInsets.top + indicatorEdgeInsets.top + indicatorSize.height / 2.0
        }
        indicatorView.center = .init(x: centerX, y: centerY)
        logoView.center = .init(x: centerX, y: centerY)

        // Label
        if indicatorHeight > 0 && !titleLabel.isHidden {
            centerY = contentInsets.top + indicatorHeight + titleEdgeInsets.top + labelSize.height / 2.0
        }
        titleLabel.center = .init(x: centerX, y: centerY)
        
        CATransaction.commit()
    }
    
    @objc private func placeSubviews(_ notification: Notification? = nil) {
        
        guard let containerView = containerView else { return }

        frame = .init(origin: .zero, size: containerView.frame.size)
        maskLayer.frame = .init(origin: .zero, size: containerView.frame.size)
        
        var keybordHeight: CGFloat = 0
        var animationDuration: TimeInterval = 0
        
        let orientation = UIApplication.shared.statusBarOrientation
        
        if let notification = notification, let keyboardInfo = notification.userInfo {
            let keyboardFrame = keyboardInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            animationDuration = keyboardInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
            if notification.name == UIResponder.keyboardWillShowNotification || notification.name == UIResponder.keyboardDidShowNotification {
                if orientation == .portrait {
                    keybordHeight = keyboardFrame?.height ?? 0
                }
            }
        } else {
            keybordHeight = visibleKeyboardHeight
        }
        
        let orenitationFrame = frame
        var statusBarFrame: CGRect = .zero
        if containerView == self.keyWindow {
            statusBarFrame = UIApplication.shared.statusBarFrame
        }
        
        // safe area bottom height
        let bottomInset: CGFloat
        if #available(iOS 11.0, *) {
            bottomInset = self.keyWindow?.safeAreaInsets.bottom ?? 0.0
        } else {
            bottomInset = 0
        }
        
        // if tabBar is hidden, bottom instantce is 24.0 + 12.0
        // otherwise, if keyboard is show, ignore tabBar height.
        let  defaultBottomInset: CGFloat
        if visibleKeyboardHeight > 0 {
            defaultBottomInset = 0
        } else {
            let tabBarHeight = self.keyWindow?.rootViewController?.tabBarController?.tabBar.frame.height ?? 24.0
            defaultBottomInset = tabBarHeight + bottomInset
        }
        
        // if navigationBar is hidden, top instantce is 24.0
        let defaultTopInset: CGFloat = self.keyWindow?.rootViewController?.navigationController?.navigationBar.frame.height ?? 24.0
        
        var activeHeight = orenitationFrame.height
        
        if keybordHeight > 0 {
            activeHeight += statusBarFrame.height * 2
        }
        
        activeHeight -= keybordHeight
        
        let distanceOfNavigationBarOrTabBar: CGFloat = 12
        
        let posY: CGFloat
        switch position {
        case .top:
            posY = defaultTopInset + statusBarFrame.height + distanceOfNavigationBarOrTabBar + baseView.frame.height * 0.5 + offset.vertical
            break
        case .center:
            posY = activeHeight * 0.45 + offset.vertical
            break
        case .bottom:
            posY = activeHeight - defaultBottomInset - distanceOfNavigationBarOrTabBar - baseView.frame.height * 0.5 + offset.vertical
            break
        }
        
        let posX = orenitationFrame.width / 2.0 + offset.horizontal

        let center: CGPoint = .init(x: posX, y: posY)
        
        if notification != nil {
            UIView.animate(withDuration: animationDuration,
                           delay: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState],
                           animations: {
                               self.baseView.center = center
                               self.baseView.setNeedsDisplay()
                           })
        } else {
            baseView.center = center
        }
    }
}

// MARK: - Event Handler

private extension ProgressHUD {
    
    @objc func overlayRecievedTouchUpInsideEvent(_ sender: UIControl) {
        NotificationCenter.default.post(name: .ProgressHUDReceivedTouchUpInsideEvent, object: self, userInfo: nil)
    }
}

// MARK: - Handle

public extension ProgressHUD {
    
    /// show a toast
    ///
    /// - Parameters:
    ///   - text: toast content
    ///   - superview: super view, if superview is nil, show on main window
    ///   - delayTimeInterval: the view will show delay the `delayTimeInterval`
    func showText(_ text: String,
                  in superview: UIView? = nil,
                  on position: Position = .bottom,
                  delay delayTimeInterval: TimeInterval = 0.0) {
        
        let displayType: DisplayType = .text(value: text)
        show(with: displayType, in: superview, on: position, delay: delayTimeInterval)
    }
    
    /// show a success message
    ///
    /// - Parameters:
    ///   - title: the success message remind users what you want
    ///   - superview: super view, if superview is nil, show on main window
    ///   - delayTimeInterval: the view will show delay the `delayTimeInterval`
    func showSuccess(with title: String = "",
                     in superview: UIView? = nil,
                     on position: Position = .center,
                     delay delayTimeInterval: TimeInterval = 0.0) {
        
        let displayType: DisplayType = .indicator(title: title, type: .success)
        show(with: displayType, in: superview, on: position, delay: delayTimeInterval)
    }
    
    /// show a error message
    ///
    /// - Parameters:
    ///   - title: the error message remind users what you want
    ///   - superview: super view, if superview is nil, show on main window
    ///   - delayTimeInterval: the view will show delay the `delayTimeInterval`
    func showError(with title: String = "",
                   in superview: UIView? = nil,
                   on position: Position = .center,
                   delay delayTimeInterval: TimeInterval = 0.0) {
        
        let displayType: DisplayType = .indicator(title: title, type: .error)
        show(with: displayType, in: superview, on: position, delay: delayTimeInterval)
    }
    
    /// show a warning message
    ///
    /// - Parameters:
    ///   - title: the warning message remind users what you want
    ///   - superview: super view, if superview is nil, show on main window
    ///   - delayTimeInterval: the view will show delay the `delayTimeInterval`
    func showWarning(with title: String = "",
                     in superview: UIView? = nil,
                     on position: Position = .center,
                     delay delayTimeInterval: TimeInterval = 0.0) {
        
        let displayType: DisplayType = .indicator(title: title, type: .warning)
        show(with: displayType, in: superview, on: position, delay: delayTimeInterval)
    }
    
    /// show a waiting alert
    ///
    /// - Parameters:
    ///   - title: the message remind users what you want
    ///   - superview: super view, if superview is nil, show on main window
    ///   - delayTimeInterval: the view will show delay the `delayTimeInterval`
    func show(with title: String = "",
              in superview: UIView? = nil,
              on position: Position = .center,
              delay delayTimeInterval: TimeInterval = 0.0) {
        
        let displayType: DisplayType = .indicator(title: title, type: .indicator(style: animationType))
        show(with: displayType, in: superview, on: position, delay: delayTimeInterval)
    }
    
    /// show the progress of some task
    ///
    /// - Parameters:
    ///   - progress: the progress of your task
    ///   - title: the message remind users what you want
    ///   - superview: super view, if superview is nil, show on main window
    ///   - delayTimeInterval: the view will show delay the `delayTimeInterval`
    func showProgress(_ progress: Float,
                      title: String = "",
                      in superview: UIView? = nil,
                      on position: Position = .center,
                      delay delayTimeInterval: TimeInterval = 0.0) {
        
        let displayType: DisplayType = .indicator(title: title, type: .progress(value: progress))
        show(with: displayType, in: superview, on: position, delay: delayTimeInterval)
    }
    
    /// show a custom image
    ///
    /// - Parameters:
    ///   - image: your image
    ///   - title: the message remind users what you want
    ///   - superview: super view, if superview is nil, show on main window
    ///   - dismissAtomically: if `true` the `HUD` will dissmiss atomically
    ///   - delayTimeInterval: the view will show delay the `delayTimeInterval`
    func showImage(_ image: UIImage,
                   title: String = "",
                   in superview: UIView? = nil,
                   on position: Position = .center,
                   dismissAtomically: Bool = true,
                   delay delayTimeInterval: TimeInterval = 0.0) {
        
        let displayType: DisplayType = .indicator(title: title, type: .image(value: image, dismissAtomically: dismissAtomically))
        show(with: displayType, in: superview, on: position, delay: delayTimeInterval)
    }
    
    /// show the animation waiting alert
    ///
    /// - Parameters:
    ///   - images: animation image array
    ///   - duration: animation duration @see UIImage
    ///   - title: the message remind users what you want
    ///   - superview: super view, if superview is nil, show on main window
    ///   - delayTimeInterval: the view will show delay the `delayTimeInterval`
    func showAnimation(_ images: [UIImage],
                       duration: TimeInterval = 0.0,
                       title: String = "",
                       in superview: UIView? = nil,
                       on position: Position = .center,
                       delay delayTimeInterval: TimeInterval = 0.0) {
        
        guard images.count > 0 else { return }
        var animationDuration = duration
        if animationDuration == 0 { animationDuration = Double(images.count) * 0.1 }
        let displayType: DisplayType = .indicator(title: title, type: .animation(value: images, duration: animationDuration))
        show(with: displayType, in: superview, on: position, delay: delayTimeInterval)
    }
    
    /// show custom display type @see ZVProgressHUD.DisplayType
    ///
    /// - Parameters:
    ///   - displayType: ZVProgressHUD.DisplayType
    ///   - superview: super view, if superview is nil, show on main window
    ///   - delayTimeInterval: the view will show delay the `delayTimeInterval`
    func show(with displayType: DisplayType,
              in superview: UIView? = nil,
              on position: Position,
              delay delayTimeInterval: TimeInterval = 0) {
        internalShow(with: displayType, in: superview, on: position, delay: delayTimeInterval)
    }
    
    /// dismiss the hud
    ///
    /// - Parameters:
    ///   - delay: the view will dissmiss delay the `delayTimeInterval`
    ///   - completion: dismiss completion handler
    func dismiss(with delayTimeInterval: TimeInterval = 0, completion: ProgressHUDCompletionHandler? = nil) {
        internalDismiss(with: delayTimeInterval, completion: completion)
    }
}

// MARK: - Props

private extension ProgressHUD {
    
    var fadeOutTimer: Timer? {
        get {
            return _fadeOutTimer
        }
        set {
            if _fadeOutTimer != nil {
                _fadeOutTimer?.invalidate()
                _fadeOutTimer = nil
            }
            
            if newValue != nil {
                _fadeOutTimer = newValue
            }
        }
    }
    
    var fadeInDeleyTimer: Timer? {
        get {
            return _fadeInDeleyTimer
        }
        set {
            if _fadeInDeleyTimer != nil {
                _fadeInDeleyTimer?.invalidate()
                _fadeInDeleyTimer = nil
            }
            
            if newValue != nil {
                _fadeInDeleyTimer = newValue
            }
        }
    }
    
    var fadeOutDelayTimer: Timer? {
        get {
            return _fadeOutDelayTimer
        }
        set {
            if _fadeOutDelayTimer != nil {
                _fadeOutDelayTimer?.invalidate()
                _fadeOutDelayTimer = nil
            }
            
            if newValue != nil {
                _fadeOutDelayTimer = newValue
            }
        }
    }
    
    var keyWindow: UIWindow? {
        var keyWindow: UIWindow?
        UIApplication.shared.windows.forEach { (window) in
            if  window.screen == UIScreen.main,
                window.isHidden == false,
                window.alpha > 0,
                window.windowLevel >= UIWindow.Level.normal,
                window.windowLevel <= maxSupportedWindowLevel {
                keyWindow = window
                return
            }
        }
        return keyWindow
    }
    
    var visibleKeyboardHeight: CGFloat {
        
        var visibleKeyboardHeight: CGFloat = 0.0
        var keyboardWindow: UIWindow?
        UIApplication.shared.windows.reversed().forEach { window in
            let windowName = NSStringFromClass(window.classForCoder)
            if #available(iOS 9.0, *) {
                if windowName == "UIRemoteKeyboardWindow" {
                    keyboardWindow = window
                    return
                }
            } else {
                if windowName == "UITextEffectsWindow" {
                    keyboardWindow = window
                    return
                }
            }
        }
        
        var possibleKeyboard: UIView?
        keyboardWindow?.subviews.forEach({ subview in
            let viewClassName = NSStringFromClass(subview.classForCoder)
            if viewClassName.hasPrefix("UI") && viewClassName.hasSuffix("InputSetContainerView") {
                possibleKeyboard = subview
                return
            }
        })
        
        possibleKeyboard?.subviews.forEach({ subview in
            let viewClassName = NSStringFromClass(subview.classForCoder)
            if viewClassName.hasPrefix("UI") && viewClassName.hasSuffix("InputSetHostView") {
                let convertedRect = possibleKeyboard?.convert(subview.frame, to: self)
                let intersectedRect = convertedRect?.intersection(self.bounds)
                visibleKeyboardHeight = intersectedRect?.height ?? 0.0
                return
            }
        })
        
        return visibleKeyboardHeight
    }
}

// MARK: - ProgressHUD.DisplayType

private extension ProgressHUD.DisplayType {

    var dismissAtomically: Bool {
        switch self {
        case .text:
            return true
        case .indicator(_, let type):
            switch type {
            case .success, .error, .warning:
                return true
            case .image(_, let dismissAtomically):
                return dismissAtomically
            default:
                return false
            }
        }
    }
    
    var title: String {
        switch self {
        case .text(let value): return value
        case .indicator(let title, _): return title ?? ""
        }
    }
    
    var indicatorType: IndicatorView.IndicatorType {
        switch self {
        case .text: return .none
        case .indicator(_, let type): return type
        }
    }    
}

// MARK: - ProgressHUD.DisplayStyle

private extension ProgressHUD.DisplayStyle {
    
    var foregroundColor: UIColor {
        switch self {
        case .dark: return .white
        case .light: return UIColor(white: 0.2, alpha: 1)
        case .custom(let color): return color.foregroundColor
        }
    }
    
    var backgroundColor: UIColor {
        switch self {
        case .dark: return UIColor(white: 0, alpha: 0.75)
        case .light: return .white
        case .custom(let color): return color.backgroundColor
        }
    }
}

// MARK: - ProgressHUD.MaskType

private extension ProgressHUD.MaskType {
    
    var backgroundColor: CGColor {
        switch self {
        case .none, .clear: return UIColor.clear.cgColor
        case .black: return UIColor.init(white: 0, alpha: 0.3).cgColor
        case .custom(let color): return color.cgColor
        }
    }
    
    var isUserInteractionEnabled: Bool {
        switch self {
        case .none: return false
        default: return true
        }
    }
}
