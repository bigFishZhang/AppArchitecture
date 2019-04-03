//
//  Model.swift
//  AppArchitecture
//
//  Created by zzb on 2019/4/3.
//  Copyright © 2019 zzb. All rights reserved.
//

import Foundation

class Model {
    
    static let textKey = "text"
    
    static let textDidChange = Notification.Name("textDidChange")
    
    var value:String {
        didSet {
            NotificationCenter.default.post(name: Model.textDidChange, object: self, userInfo: [Model.textKey:value])
        }
        

    }
    init(value:String) {
        self.value = value
    }
    
    
    
    
    
    
    
    
    
    
}
