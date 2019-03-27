//
//  SimpleSideController.swift
//  SimpleSideController
//
//  Created by Alessandro Martin on 21/08/16.
//  Copyright © 2016 Alessandro Martin. All rights reserved.
//

import UIKit

public protocol SimpleSideControllerDelegate: class {
    func sideController(_ sideController: SimpleSideController, willChangeTo state: SimpleSideController.Presenting)
    func sideController(_ sideController: SimpleSideController, didChangeTo state: SimpleSideController.Presenting)
}

public struct Border {
    let thickness: CGFloat
    let color: UIColor
    
    public init(thickness: CGFloat, color: UIColor){
        self.thickness = thickness
        self.color = color
    }
}

public struct Shadow {
    let opacity: CGFloat
    let radius: CGFloat
    let width: CGFloat
    
    public init(opacity: CGFloat, radius: CGFloat, width: CGFloat) {
        self.opacity = opacity
        self.radius = radius
        self.width = width
    }
}

public class SimpleSideController: UIViewController {
    
    public enum Presenting {
        case front
        case side
        case transitioning
    }
    
    public enum Background {
        case opaque(color: UIColor, shadow: Shadow?)
        case translucent(style: UIBlurEffect.Style, color: UIColor)
        case vibrant(style: UIBlurEffect.Style, color: UIColor)
    }
    
    static let speedThreshold: CGFloat = 300.0
    
    fileprivate let sideContainerView = UIView()
    fileprivate var sideContainerWidthConstraint: NSLayoutConstraint?
    fileprivate var sideContainerHorizontalConstraint: NSLayoutConstraint?
    
    fileprivate let borderView = UIView()
    fileprivate var borderWidthConstraint: NSLayoutConstraint?
    
//MARK: Public properties
    public weak var delegate: SimpleSideControllerDelegate?
    
    public var state: Presenting {
        return self._state
    }
    
    public var border: Border? {
        didSet {
            self.borderView.backgroundColor = (border?.color) ?? .lightGray
            self.borderWidthConstraint?.constant = (border?.thickness) ?? 0.0
            self.sideContainerView.layoutIfNeeded()
        }
    }
    
//MARK: Private properties
    fileprivate(set) var _state: Presenting {
        willSet(newState) {
            self.performTransition(to: newState)
            self.delegate?.sideController(self, willChangeTo: newState)
        }
        didSet {
            switch self._state {
            case .front:
                self.disableTapGesture()
                self.frontController.view.isUserInteractionEnabled = true
            case .side:
                self.enablePanGesture()
                self.frontController.view.isUserInteractionEnabled = false
            default:
                break
            }
        }
    }
    
    fileprivate var shadow: Shadow? {
        didSet {
            if self._state == .side {
                self.sideContainerView.layer.shadowOpacity = Float((self.shadow?.opacity) ?? 0.3)
                self.sideContainerView.layer.shadowRadius = (self.shadow?.radius) ?? 5.0
                self.sideContainerView.layer.shadowOffset = CGSize(width: ((self.shadow?.width) ?? 7.0) * (self.view.isRightToLeftLanguage() ? -1.0 : 1.0),
                                                                   height: 0.0)
            }
        }
    }
    
    fileprivate var background: Background {
        didSet {
            switch self.background {
            case let .opaque(color, shadow):
                self.sideContainerView.backgroundColor = color
                self.shadow = shadow
            case let .translucent(_, color), let .vibrant(_, color):
                self.sideContainerView.backgroundColor = color
            }
        }
    }
    
    fileprivate var frontController: UIViewController
    fileprivate var sideController: UIViewController
    fileprivate var panGestureRecognizer: UIPanGestureRecognizer?
    fileprivate var panPreviousLocation: CGPoint = .zero
    fileprivate var panPreviousVelocity: CGPoint = .zero
    fileprivate var tapGestureRecognizer: UITapGestureRecognizer?
    fileprivate var sideContainerWidth: CGFloat
    fileprivate var blurView: UIVisualEffectView?
    fileprivate var vibrancyView: UIVisualEffectView?
    
    fileprivate lazy var presentedSideHorizontalPosition: CGFloat = {
        let isRTL = self.view.isRightToLeftLanguage()
        return isRTL ? UIScreen.main.bounds.width : self.sideContainerWidth
    }()
    
    fileprivate lazy var initialSideHorizontalPosition: CGFloat = {
        let isRTL = self.view.isRightToLeftLanguage()
        return isRTL ? UIScreen.main.bounds.width + self.sideContainerWidth : 0.0
    }()
    
	required public init(frontController: UIViewController, sideController: UIViewController, sideContainerWidth: CGFloat, background: Background) {
        self.frontController = frontController
        self.sideController = sideController
        self.sideContainerWidth = sideContainerWidth
        self.background = background
        self._state = .front
    
        super.init(nibName: nil, bundle: nil)
    }
	
	// Objective-C compatible init:
	public init(frontController: UIViewController, sideController: UIViewController, sideContainerWidth: CGFloat,
                backgroundColor: UIColor, blurEffectStyle: UIBlurEffect.Style) {
		self.frontController = frontController
		self.sideController = sideController
		self.sideContainerWidth = sideContainerWidth
		self.background = .translucent(style: blurEffectStyle, color: backgroundColor)
		self._state = .front

		super.init(nibName: nil, bundle: nil)
	}
	
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()

        self.setup()
    }
}

//MARK: Public API
extension SimpleSideController {
    public func showFrontController() {
        self._state = .front
    }
    
    public func showSideController() {
        self._state = .side
    }
    
    public func isPanGestureEnabled() -> Bool {
        return self.panGestureRecognizer?.isEnabled ?? false
    }
    
    public func disablePanGesture() {
        self.panGestureRecognizer?.isEnabled = false
    }
    
    public func enablePanGesture() {
        self.panGestureRecognizer?.isEnabled = true
    }
    
    public func isTapGestureEnabled() -> Bool {
        return self.tapGestureRecognizer?.isEnabled ?? false
    }
    
    public func disableTapGesture() {
        self.tapGestureRecognizer?.isEnabled = false
    }
    
    public func enableTapGesture() {
        self.tapGestureRecognizer?.isEnabled = true
    }
	
	@objc public func isSideControllerVisible() -> Bool {
		return self._state == .side
	}
}

//MARK: Gesture management
extension SimpleSideController {
    @objc fileprivate func handleTapGesture(gr: UITapGestureRecognizer) {
        switch self._state {
        case .front:
            self._state = .side
        case .side:
            self._state = .front
        case .transitioning:
            break
        }
    }

    @objc fileprivate func handlePanGesture(gr: UIPanGestureRecognizer) {
        switch gr.state {
        case .began:
            if let opacity = self.shadow?.opacity, self._state == .front {
                self.sideContainerView.displayShadow(opacity: opacity)
            }
            
            self._state = .transitioning
            self.handlePanGestureBegan(with: gr)
        case .changed:
            self.handlePanGestureChanged(with: gr)
        default:
            self.handlePanGestureEnded(with: gr)
        }
    }
    
    private func handlePanGestureBegan(with recognizer: UIPanGestureRecognizer) {
        self.panPreviousLocation = recognizer.location(in: self.view)
    }
    
    private func handlePanGestureChanged(with recognizer: UIPanGestureRecognizer) {
        guard let constraint = self.sideContainerHorizontalConstraint else { return }
        
        let currentLocation = recognizer.location(in: self.view)
        self.panPreviousVelocity = recognizer.velocity(in: self.view)
        self.sideContainerHorizontalConstraint?.constant += currentLocation.x - self.panPreviousLocation.x
        self.sideContainerHorizontalConstraint?.constant = clamp(lowerBound: 0.0,
                                                                value: constraint.constant,
                                                                upperBound: self.sideContainerWidth)
        self.panPreviousLocation = currentLocation
    }
    
    private func handlePanGestureEnded(with recognizer: UIPanGestureRecognizer) {
        guard let constraint = self.sideContainerHorizontalConstraint else { return }
        
        let xSideLocation = constraint.constant
        let xSpeed = self.panPreviousVelocity.x
        
        if xSpeed > SimpleSideController.speedThreshold {
            self._state = .side
        } else if xSpeed < -SimpleSideController.speedThreshold {
            self._state = .front
        } else if xSideLocation > self.sideContainerWidth / 2.0 {
            self._state = .side
        } else {
            self._state = .front
        }
        
        self.panPreviousLocation = .zero
        self.panPreviousVelocity = .zero
    }
}

//MARK: Setup
extension SimpleSideController {
    fileprivate func setup() {
        self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(gr:)))
        self.tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(gr:)))
        self.tapGestureRecognizer?.delegate = self
        self.view.addGestureRecognizer(self.panGestureRecognizer!)
        self.panGestureRecognizer?.maximumNumberOfTouches = 1
        self.view.addGestureRecognizer(self.tapGestureRecognizer!)
        self.tapGestureRecognizer?.isEnabled = false
        
        self.addChild(self.frontController)
        self.view.addSubview(self.frontController.view)
        self.frontController.view.frame = self.view.bounds
        self.frontController.didMove(toParent: self)
        
        self.view.addSubview(self.sideContainerView)
        self.constrainSideContainerView()
        
        self.sideContainerView.addSubview(self.borderView)
        self.constrainBorderView()
        
        self.view.bringSubviewToFront(self.sideContainerView)
        self.sideContainerView.hideShadow(animation: 0.0)
        
        switch self.background {
        case let .translucent(style, color):
            self.sideContainerView.backgroundColor = color
            let blurEffect = UIBlurEffect(style: style)
            self.blurView = UIVisualEffectView(effect: blurEffect)
            self.sideContainerView.insertSubview(self.blurView!, at: 0)
            self.pinIntoSideContainer(view: self.blurView!)
            self.addChild(self.sideController)
            self.blurView?.contentView.addSubview(self.sideController.view)
            self.pinIntoSuperView(view: self.sideController.view)
            self.sideController.didMove(toParent: self)
        case let .vibrant(style, color):
            self.sideContainerView.backgroundColor = color
            let blurEffect = UIBlurEffect(style: style)
            self.blurView = UIVisualEffectView(effect: blurEffect)
            let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
            self.vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
            self.sideContainerView.insertSubview(self.blurView!, at: 0)
            self.pinIntoSideContainer(view: self.blurView!)
            self.addChild(self.sideController)
            self.blurView?.contentView.addSubview(self.vibrancyView!)
            self.pinIntoSuperView(view: self.vibrancyView!)
            self.vibrancyView?.contentView.addSubview(self.sideController.view)
            self.pinIntoSuperView(view: self.sideController.view)
            self.sideController.didMove(toParent: self)
        case let .opaque(color, shadow):
            self.sideController.view.backgroundColor = color
            self.shadow = shadow
            self.addChild(self.sideController)
            self.sideContainerView.addSubview(self.sideController.view)
            self.pinIntoSideContainer(view: self.sideController.view)
            self.sideController.didMove(toParent: self)
        }
    }
}

extension SimpleSideController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return gestureRecognizer == self.tapGestureRecognizer &&
        !self.sideContainerView.frame.contains(touch.location(in: self.view))
    }
}

//MARK: Utilities
extension SimpleSideController {
    fileprivate func performTransition(to state: Presenting) {
        switch state {
        case .front:
            self.view.layoutIfNeeded()
            self.sideContainerHorizontalConstraint?.constant = self.initialSideHorizontalPosition
            self.tapGestureRecognizer?.isEnabled = false
            self.sideContainerView.hideShadow()
            UIView.animate(withDuration: 0.25,
                           delay: 0.0,
                           options: .curveEaseIn,
                           animations: {
                            self.view.layoutIfNeeded()
            }) { finished in
                if finished {
                    self.delegate?.sideController(self, didChangeTo: state)
                }
            }
        case .side:
            self.view.layoutIfNeeded()
            self.sideContainerHorizontalConstraint?.constant = self.presentedSideHorizontalPosition
            self.tapGestureRecognizer?.isEnabled = true
            if let opacity = self.shadow?.opacity {
                self.sideContainerView.displayShadow(opacity: opacity)
            }
            UIView.animate(withDuration: 0.25,
                           delay: 0.0,
                           options: .curveEaseOut,
                           animations: {
                            self.view.layoutIfNeeded()
            }) { finished in
                if finished {
                    self.delegate?.sideController(self, didChangeTo: state)
                }
            }
        case .transitioning:
            break
        }
    }
    
    fileprivate func pinIntoSideContainer(view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        let top = NSLayoutConstraint(item: view,
                                     attribute: .top,
                                     relatedBy: .equal,
                                     toItem: self.sideContainerView,
                                     attribute: .top,
                                     multiplier: 1.0,
                                     constant: 0.0)
        let bottom = NSLayoutConstraint(item: view,
                                        attribute: .bottom,
                                        relatedBy: .equal,
                                        toItem: self.sideContainerView,
                                        attribute: .bottom,
                                        multiplier: 1.0,
                                        constant: 0.0)
        let leading = NSLayoutConstraint(item: view,
                                         attribute: .leading,
                                         relatedBy: .equal,
                                         toItem: self.sideContainerView,
                                         attribute: .leading,
                                         multiplier: 1.0,
                                         constant: 0.0)
        let trailing = NSLayoutConstraint(item: view,
                                          attribute: .trailing,
                                          relatedBy: .equal,
                                          toItem: self.borderView,
                                          attribute: .leading,
                                          multiplier: 1.0,
                                          constant: 0.0)
        NSLayoutConstraint.activate([top, bottom, leading, trailing])
    }
    
    fileprivate func pinIntoSuperView(view : UIView) {
        guard let superView = view.superview else { fatalError("\(view) does not have a superView!") }
        
        view.translatesAutoresizingMaskIntoConstraints = false
        let top = NSLayoutConstraint(item: view,
                                     attribute: .top,
                                     relatedBy: .equal,
                                     toItem: superView,
                                     attribute: .top,
                                     multiplier: 1.0,
                                     constant: 0.0)
        let bottom = NSLayoutConstraint(item: view,
                                        attribute: .bottom,
                                        relatedBy: .equal,
                                        toItem: superView,
                                        attribute: .bottom,
                                        multiplier: 1.0,
                                        constant: 0.0)
        let leading = NSLayoutConstraint(item: view,
                                         attribute: .leading,
                                         relatedBy: .equal,
                                         toItem: superView,
                                         attribute: .leading,
                                         multiplier: 1.0,
                                         constant: 0.0)
        let trailing = NSLayoutConstraint(item: view,
                                          attribute: .trailing,
                                          relatedBy: .equal,
                                          toItem: superView,
                                          attribute: .trailing,
                                          multiplier: 1.0,
                                          constant: 0.0)
        NSLayoutConstraint.activate([top, bottom, leading, trailing])
    }
    
    fileprivate func constrainSideContainerView() {
        self.sideContainerView.translatesAutoresizingMaskIntoConstraints = false
        let height = NSLayoutConstraint(item: self.sideContainerView,
                                        attribute: .height,
                                        relatedBy: .equal,
                                        toItem: self.view,
                                        attribute: .height,
                                        multiplier: 1.0,
                                        constant: 0.0)
        let centerY = NSLayoutConstraint(item: self.sideContainerView,
                                         attribute: .centerY,
                                         relatedBy: .equal,
                                         toItem: self.view,
                                         attribute: .centerY,
                                         multiplier: 1.0,
                                         constant: 0.0)
        self.sideContainerWidthConstraint = NSLayoutConstraint(item: self.sideContainerView,
                                                               attribute: .width,
                                                               relatedBy: .equal,
                                                               toItem: nil,
                                                               attribute: .notAnAttribute,
                                                               multiplier: 1.0,
                                                               constant: self.sideContainerWidth)
        self.sideContainerHorizontalConstraint = NSLayoutConstraint(item: self.sideContainerView,
                                                                    attribute: .trailing,
                                                                    relatedBy: .equal,
                                                                    toItem: self.view,
                                                                    attribute: .leading,
                                                                    multiplier: 1.0,
                                                                    constant: self.initialSideHorizontalPosition)
        NSLayoutConstraint.activate([height, centerY, self.sideContainerWidthConstraint!, self.sideContainerHorizontalConstraint!])
    }
    
    fileprivate func constrainBorderView() {
        self.borderView.translatesAutoresizingMaskIntoConstraints = false
        let top = NSLayoutConstraint(item: self.borderView,
                                     attribute: .top,
                                     relatedBy: .equal,
                                     toItem: self.sideContainerView,
                                     attribute: .top,
                                     multiplier: 1.0,
                                     constant: 0.0)
        let bottom = NSLayoutConstraint(item: self.borderView,
                                        attribute: .bottom,
                                        relatedBy: .equal,
                                        toItem: self.sideContainerView,
                                        attribute: .bottom,
                                        multiplier: 1.0,
                                        constant: 0.0)
        self.borderWidthConstraint = NSLayoutConstraint(item: self.borderView,
                                                        attribute: .width,
                                                        relatedBy: .equal,
                                                        toItem: nil,
                                                        attribute: .notAnAttribute,
                                                        multiplier: 1.0,
                                                        constant: self.border?.thickness ?? 0.0)
        let side = NSLayoutConstraint(item: self.borderView,
                                      attribute: .trailing,
                                      relatedBy: .equal,
                                      toItem: self.sideContainerView,
                                      attribute: .trailing,
                                      multiplier: 1.0,
                                      constant: 0.0)
        NSLayoutConstraint.activate([top, bottom, self.borderWidthConstraint!, side])
    }
}
