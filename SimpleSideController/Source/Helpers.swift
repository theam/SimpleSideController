//
//  Helpers.swift
//  SimpleSideController
//
//  Created by Alessandro Martin on 21/08/16.
//  Copyright © 2016 Alessandro Martin. All rights reserved.
//

import UIKit

extension UIView {
    func isRightToLeftLanguage() -> Bool {
        if #available(iOS 9.0, *) {
            return UIView.userInterfaceLayoutDirection(for: self.semanticContentAttribute) == .rightToLeft
        } else {
            return NSLocale.characterDirection(forLanguage: NSLocale.preferredLanguages[0]) == .rightToLeft
        }
    }
    
    func displayShadow(opacity: CGFloat = 1.0, animation duration: CFTimeInterval = 0.25) {
        self.setShadowOpacity(to: opacity, animation: duration)
    }
    
    func hideShadow(animation duration: CFTimeInterval = 0.25) {
        self.setShadowOpacity(to: 0.0, animation: duration)
    }
    
    private func setShadowOpacity(to toValue: CGFloat, animation duration: CFTimeInterval) {
        let anim = CABasicAnimation(keyPath: "shadowOpacity")
        anim.fromValue = self.layer.shadowOpacity
        anim.toValue = toValue
        anim.duration = duration
        self.layer.add(anim, forKey: "shadowOpacity")
        self.layer.shadowOpacity = Float(toValue)
    }
}

extension UIViewController {
    var simpleSideController: SimpleSideController? {
        get {
            return simpleSideController(for: self)
        }
    }
    
    private func simpleSideController(for viewController: UIViewController?) -> SimpleSideController? {
        guard let viewController = viewController else { return nil }
        
        switch viewController {
        case let viewController as SimpleSideController:
            return viewController
        default:
            return simpleSideController(for: viewController.parent)
        }
    }
}

func clamp<T: Comparable>(lowerBound lower: T, value: T, upperBound: T) -> T {
    return max(min(value, upperBound), lower)
}
