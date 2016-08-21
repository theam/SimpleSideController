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

public class SimpleSideController: UIViewController {
    
    public enum Presenting {
        case front
        case side
        case transitioning
    }
    
    public enum Background {
        case opaque(UIColor, Shadow?)
        case translucent
    }
    
    public struct Border {
        let thickness: CGFloat
        let color: UIColor
    }
    
    public struct Shadow {
        let opacity: CGFloat
        let radius: CGFloat
        let width: CGFloat
    }
    
    static let speedThreshold: CGFloat = 300.0
    
    @IBOutlet fileprivate weak var sideContainerView: UIView!
    @IBOutlet fileprivate weak var sideContainerWidthConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var sideContainerHorizontalConstraint: NSLayoutConstraint!
    
    @IBOutlet fileprivate weak var borderView: UIView!
    @IBOutlet fileprivate weak var borderWidthConstraint: NSLayoutConstraint!
    
//MARK: Public properties
    public weak var delegate: SimpleSideControllerDelegate?
    
    public var border: Border? {
        didSet {
            self.borderView.backgroundColor = (border?.color) ?? .lightGray
            self.borderWidthConstraint.constant = (border?.thickness) ?? 1.0
            self.sideContainerView.layoutIfNeeded()
        }
    }
    
//MARK: Private properties
    fileprivate(set) var state: Presenting {
        willSet(newState) {
            if newState != self.state {
                self.performTransition(to: newState)
                self.delegate?.sideController(self, willChangeTo: newState)
            }
        }
    }
    
    fileprivate var shadow: Shadow? {
        didSet {
            if self.state == .side {
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
            case .translucent:
                self.sideContainerView.backgroundColor = .clear
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
        
        self.state = .front
        
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
        self.state = .front
    }
    
    public func showSideController() {
        self.state = .side
    }
}

//MARK: Gesture management
extension SimpleSideController {
    @objc fileprivate func handlePanGesture(gr: UIPanGestureRecognizer) {
        switch gr.state {
        case .began:
            self.state = .transitioning
            self.handlePanGestureBegan(with: gr)
        case .changed:
            self.handlePanGestureChanged(with: gr)
        default:
            self.handlePanGestureEnded(with: gr)
        }
    }
    
    @objc fileprivate func handleTapGesture(gr: UITapGestureRecognizer) {
        guard  !self.sideContainerView.frame.contains(gr.location(in: self.view)) else { return }
        
        switch self.state {
        case .front:
            self.performTransition(to: .side)
        case .side:
            self.performTransition(to: .front)
        case .transitioning:
        break
        }
    }
    
    private func handlePanGestureBegan(with recognizer: UIPanGestureRecognizer) {
        self.panPreviousLocation = recognizer.location(in: self.view)
    }
    
    private func handlePanGestureChanged(with recognizer: UIPanGestureRecognizer) {
        let currentLocation = recognizer.location(in: self.view)
        self.panPreviousVelocity = recognizer.velocity(in: self.view)
        self.sideContainerHorizontalConstraint.constant += currentLocation.x - self.panPreviousLocation.x
        self.sideContainerHorizontalConstraint.constant = clamp(lowerBound: 0.0,
                                                                value: self.sideContainerHorizontalConstraint.constant,
                                                                upperBound: self.sideContainerWidth)
        self.panPreviousLocation = currentLocation
    }
    
    private func handlePanGestureEnded(with recognizer: UIPanGestureRecognizer) {
        let xSideLocation = self.sideContainerHorizontalConstraint.constant
        let xSpeed = self.panPreviousVelocity.x
        
        if xSpeed > SimpleSideController.speedThreshold {
            self.state = .side
        } else if xSpeed < -SimpleSideController.speedThreshold {
            self.state = .front
        } else if xSideLocation > self.sideContainerWidth / 2.0 {
            self.state = .side
        } else {
            self.state = .front
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
        self.view.addGestureRecognizer(self.panGestureRecognizer!)
        self.panGestureRecognizer?.maximumNumberOfTouches = 1
        self.view.addGestureRecognizer(self.tapGestureRecognizer!)
        self.tapGestureRecognizer?.isEnabled = false
        
        self.addChildViewController(self.frontController)
        self.view.addSubview(self.frontController.view)
        self.frontController.view.frame = self.view.bounds
        self.frontController.didMove(toParentViewController: self)
        
        self.sideContainerWidthConstraint.constant = self.sideContainerWidth
        self.sideContainerHorizontalConstraint.constant = self.initialSideHorizontalPosition
        self.view.bringSubview(toFront: self.sideContainerView)
        self.sideContainerView.hideShadow(animation: 0.0)
        
        ///
        switch self.background {
        case .translucent:
            self.sideContainerView.backgroundColor = UIColor(white: 1.0, alpha: 0.3)
            let blurEffect = UIBlurEffect(style: .light)
            self.blurView = UIVisualEffectView(effect: blurEffect)
            let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
            self.vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
            self.sideContainerView.insertSubview(self.blurView!, at: 0)
            self.pinIntoSideContainer(view: self.blurView!)
            self.addChildViewController(self.sideController)
            self.vibrancyView?.contentView.addSubview(self.sideController.view)
            self.pinIntoSuperView(view: self.sideController.view)
            self.sideController.didMove(toParentViewController: self)
            blurView?.contentView.addSubview(vibrancyView!)
        case .opaque(_, _):
            self.addChildViewController(self.sideController)
            self.sideContainerView.addSubview(self.sideController.view)
            self.pinIntoSideContainer(view: self.sideController.view)
            self.sideController.didMove(toParentViewController: self)
        }
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
                self.delegate?.sideController(self, didChangeTo: state)
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
                self.delegate?.sideController(self, didChangeTo: state)
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
}
