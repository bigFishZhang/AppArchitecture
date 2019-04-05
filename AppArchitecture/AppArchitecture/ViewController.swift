//
//  ViewController.swift
//  AppArchitecture
//
//  Created by zzb on 2019/4/3.
//  Copyright © 2019 zzb. All rights reserved.
//

import UIKit
import CwlSignal
import CwlUtils

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
    var minimalViewModel:MinimalViewModel?
    var minimalObserver:NSObjectProtocol?
    var viewModel:ViewModel?
    var mvvmObserver:Cancellable? //单一的观察者 和RxSwift 中的 Disposable 一样的概念
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //mvc
        mvcDidLoad()
        
        //mvp
        mvpDidLoad()
        
        //mvvm
        mvvmMinimalViewDidLoad()
        
        mvvmDidLoad()
        

    }
    
    
    
}

// ------------------------------------------  MVC  ------------------------------------------------

extension ViewController {
    func mvcDidLoad() {
       //Initialize
       mvcTextField.text = model.value;
       //add observer
      // model to c  c 持有view c可以直接修改view
       mvcObserver = NotificationCenter.default.addObserver(forName: Model.textDidChange, object: nil, queue: nil) { [mvcTextField] (note) in
            mvcTextField?.text = note.userInfo?[Model.textKey] as? String
        }
    }
    
    // view to c  c to Model
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
        //model to presenter presenter持有view presenter可以直接修改持有的View
        observer = NotificationCenter.default.addObserver(forName: Model.textDidChange, object: nil, queue: nil) { [view] (note) in
            view.textFieldValue = note.userInfo?[Model.textKey] as? String ?? ""
        }
    }
    
    // view to presenter  to  model
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
        // presenter 持有view
        presenter = ViewPresenter(model: model, view: self)
        
    }
    //view 事件 传递给 presenter 执行s
    @IBAction func  mvpButtonPressed() {
        presenter?.commit()
        print("mvpButtonPressed")
    }
    
}



// ------------------------------------------  Minimal MVVM ------------------------------------------------

class MinimalViewModel:NSObject {
    let model: Model
    var observer: NSObjectProtocol?
    
    @objc dynamic var textFeildValue:String
    
    
    init(model:Model) {
        self.model = model
        textFeildValue = model.value
        super.init()
        // model to viewModel
        observer = NotificationCenter.default.addObserver(forName: Model.textDidChange, object: nil, queue: nil) { [weak self] (note) in
            self?.textFeildValue = note.userInfo?[Model.textKey] as? String ?? ""
        }
    }
    
    //view to model
    func commit(value:String)  {
        
        model.value = value
    }
    
}


extension ViewController {
    
    func mvvmMinimalViewDidLoad() {
        
        minimalViewModel = MinimalViewModel(model:model)
        //viewModel to view
        minimalObserver = minimalViewModel?.observe(\.textFeildValue, options: [.initial,.new]) { [weak self](_,change) in
            self?.mvvmmTextField.text = change.newValue
        }
    }
    
    @IBAction func  mvvmmButtonPressed() {
        print("mvvmmButtonPressed")
       minimalViewModel?.commit(value: mvvmmTextField.text ?? "")
    }
}

// ------------------------------------------  MVVM ------------------------------------------------
class ViewModel{
    
    let model: Model
    
    init(model:Model) {
        self.model = model
    }
    var textFieldValue: Signal<String> {
        // model to compactMap to  continuous to viewModel
        return Signal
            .notifications(name:Model.textDidChange)
            .compactMap { note in note.userInfo?[Model.textKey] as? String
            }.continuous(initialValue:model.value)
    }
    
    //view to model
    func commit(value:String){
        model.value = value
    }
}



extension ViewController {
    
    func mvvmDidLoad() {
        viewModel = ViewModel(model: model)
        mvvmObserver =  viewModel?.textFieldValue.subscribeValues({ [unowned self] (str) in
            self.mvvmTextField.text = str
        })
    
    }
    
    @IBAction func  mvvmButtonPressed() {
        print("mvvmButtonPressed")
        viewModel?.commit(value: self.mvvmTextField.text ?? "")
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
