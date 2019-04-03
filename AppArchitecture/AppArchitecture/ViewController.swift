//
//  ViewController.swift
//  AppArchitecture
//
//  Created by zzb on 2019/4/3.
//  Copyright © 2019 zzb. All rights reserved.
//

import UIKit

class ViewController: UIViewController,UITextFieldDelegate {

    let model = Model(value: "initial value")
    
    
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
    
    var mvcObserver: NSObjectProtocol?
    var presenter: ViewPresenter?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //mvc
        mvcDidLoad()
        
        //mvp
        mvpDidLoad()
        

    }
    
    
    
}

// ------------------------------------------  MVC  ------------------------------------------------

extension ViewController {
    func mvcDidLoad() {
       //Initialize
       mvcTextField.text = model.value;
       //add observer
       mvcObserver = NotificationCenter.default.addObserver(forName: Model.textDidChange, object: nil, queue: nil) { [mvcTextField] (note) in
            mvcTextField?.text = note.userInfo?[Model.textKey] as? String
        }
    }
    
    @IBAction func mvcButtonPressed(){
        print("mvcButtonPressed")
        model.value = mvcTextField.text ?? ""
        
    }
    
    
}


// ------------------------------------------  MVP  ------------------------------------------------

protocol viewProtocol: class {
    
    var textFieldValue: String {get set}
}

class ViewPresenter {
    let model:Model
    weak var view:viewProtocol?
    let observer:NSObjectProtocol
    
    init(model:Model,view:viewProtocol) {
        self.model = model
        self.view = view
        //Initialize
        view.textFieldValue = model.value;
        //add observer
        observer = NotificationCenter.default.addObserver(forName: Model.textDidChange, object: nil, queue: nil) { [view] (note) in
            view.textFieldValue = note.userInfo?[Model.textKey] as? String ?? ""
        }
    }
    
    func commit()  {
        model.value = view?.textFieldValue ?? ""
    }
    
}

extension ViewController :viewProtocol {
    
    var textFieldValue: String {
        get {
            return mvpTextField.text ?? ""
        }
        set {
            mvpTextField.text = newValue
        }
    }
    
    func mvpDidLoad() {
        
        presenter = ViewPresenter(model: model, view: self)
        
    }

    @IBAction func  mvpButtonPressed() {
        presenter?.commit()
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
