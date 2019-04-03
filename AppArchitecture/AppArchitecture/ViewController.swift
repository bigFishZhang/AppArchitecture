//
//  ViewController.swift
//  AppArchitecture
//
//  Created by zzb on 2019/4/3.
//  Copyright © 2019 zzb. All rights reserved.
//

import UIKit

class ViewController: UIViewController,UITextFieldDelegate {

    @IBOutlet weak var mvcTextField: UITextField!
    @IBOutlet var mvpTextField: UITextField!
    @IBOutlet var mvvmmTextField: UITextField!
    @IBOutlet var mvvmTextField: UITextField!
    @IBOutlet var mvcvsTextField: UITextField!
    @IBOutlet var mavbTextField: UITextField!
    @IBOutlet var cleanTextField: UITextField!
    
    @IBOutlet var mvcButton: UIButton!
    @IBOutlet var mvpButton: UIButton!
    @IBOutlet var mvvmmButton: UIButton!
    @IBOutlet var mvvmButton: UIButton!
    @IBOutlet var mvcvsButton: UIButton!
    @IBOutlet var mavbButton: UIButton!
    @IBOutlet var cleanButton: UIButton!
    
    @IBOutlet var stackView: UIStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    
    
}

// ------------------------------------------  MVC  ------------------------------------------------

extension ViewController {
    
    @IBAction func mvcButtonPressed(){
        print("mvcButtonPressed")
        
    }
    
    
}


// ------------------------------------------  MVP  ------------------------------------------------
extension ViewController {
    
    @IBAction func  mvpButtonPressed() {
        print("mvpButtonPressed")
    }
    
}


// ------------------------------------------  Minimal MVVM ------------------------------------------------
extension ViewController {
    @IBAction func  mvvmmButtonPressed() {
        print("mvvmmButtonPressed")
    }
}

// ------------------------------------------  MVVM ------------------------------------------------
extension ViewController {
    @IBAction func  mvvmButtonPressed() {
        print("mvvmButtonPressed")
    }
}

// ------------------------------------------  MVC+VS ------------------------------------------------
extension ViewController {
    @IBAction func mvcvsButtonPressed() {
         print("mvcvsButtonPressed")
    }
}


// ------------------------------------------  TEA ------------------------------------------------
extension ViewController {
    
}

// ------------------------------------------  MAVB ------------------------------------------------
extension ViewController {
   
}

// ------------------------------------------  Clean ------------------------------------------------
extension ViewController {
    @IBAction func  cleanButtonPressed() {
        print("cleanButtonPressed")
    }
}
