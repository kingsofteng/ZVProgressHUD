//
//  Configration.swift
//  ZVProgressHUD
//
//  Created by 张伟 on 2018/2/13.
//  Copyright © 2018年 zevwings. All rights reserved.
//

import UIKit

public extension Notification.Name {
    struct ZVProgressHUD {
        public static let ReceivedTouchEvent = Notification.Name(rawValue: "com.zevwings.progresshud.touchup.inside")
    }
}

extension UIImage {
    convenience init?(resource name: String) {
        guard let path = Bundle(for: ZVProgressHUD.self).path(forResource: "Resource", ofType: "bundle") else { return nil }
        let bundle = Bundle(path: path)
        guard let fileName = bundle?.path(forResource: name, ofType: "png") else { return nil }
        self.init(contentsOfFile: fileName)
    }
}

extension UILabel {
    
    class var `default`: UILabel {
        let defaultLabel = UILabel()
        defaultLabel.minimumScaleFactor = 0.5
        defaultLabel.textAlignment = .center
        defaultLabel.isUserInteractionEnabled = false
        defaultLabel.font = .systemFont(ofSize: 16.0)
        defaultLabel.backgroundColor = .clear
        defaultLabel.lineBreakMode = .byTruncatingTail
        defaultLabel.numberOfLines = 0
        return defaultLabel
    }
    
    func getTextWidth(with maxSize: CGSize) -> CGSize {
        guard let text = self.text, !text.isEmpty else { return .zero }
        let attributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: self.font]
        return (text as NSString).boundingRect(with: maxSize, options: .usesLineFragmentOrigin, attributes: attributes, context: nil).size
    }
    
}

