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
    var viewState:ViewState?
    var viewStateObserver :NSObjectProtocol?
    var viewStateModelObserver :NSObjectProtocol?
    var driver : Driver<ElmState,ElmState.Action>?
    //viewStateadapter
//    var viewStateAdaptet :Var<String>!
    
    var cleanPresenter: CleanPresenter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //mvc
        mvcDidLoad()
        
        //mvp
        mvpDidLoad()
        
        //mvvm
        mvvmMinimalViewDidLoad()
        
        mvvmDidLoad()
        
        mvcvsDidLoad()
        
        elmDidLoad()
        
//        mavbDidLoad()
        
        cleanDidLoad()

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

class ViewState {
    var textFieldValue:String = ""
    
    init(textFieldValue:String) {
        self.textFieldValue = textFieldValue
        
    }
    
}



extension ViewController {
    func mvcvsDidLoad() {
        viewState = ViewState(textFieldValue:model.value)
        mvcvsTextField.text = model.value
        //实时监听 mvcvsTextField的属性存储到 viewState
        viewStateObserver = NotificationCenter.default.addObserver(forName:UITextField.textDidChangeNotification, object: mvcvsTextField, queue: nil, using: { [viewState] (note) in
            viewState?.textFieldValue = (note.object as! UITextField).text ?? ""
        })
        //model 的值监听传来viewController 再 赋值给view
        viewStateModelObserver = NotificationCenter.default.addObserver(forName: Model.textDidChange, object: nil, queue: nil, using: { [mvcvsTextField] (note) in
            mvcvsTextField?.text = note.userInfo?[Model.textKey] as? String
        })
    }
    
    //事件点击的时候 把viewState存储的值传递到 model
    @IBAction func mvcvsButtonPressed() {
        print("mvcvsButtonPressed")
        model.value = viewState?.textFieldValue ?? ""
    }
}


// ------------------------------------------  Elm ------------------------------------------------

struct ElmState {
    var text:String
    enum Action {
        case commit
        case setText(String)
        case modelNotification(Notification)
    }
    
    mutating func update(_ action:Action) ->Command<Action>? {
        switch action {
            case .commit:
                return Command.changeModelText(text)
            case .setText(let text):
                self.text = text
                return nil
            case .modelNotification(let note):
                text = note.userInfo?[Model.textKey] as? String ?? ""
                return nil
        }
        
    }
    
    var view: [ElmView<Action>] {
        return [
            ElmView.textField(text, onChange: Action.setText),
            ElmView.button(title: "Commit", onTap: Action.commit)
        ]
    }
    //subscriptions
    var subscriptions: [Subscription<Action>] {
        return [
            .notification(name: Model.textDidChange, Action.modelNotification)
        ]
    }

}

extension ViewController {
    func elmDidLoad() {
        driver = Driver.init(ElmState(text: model.value), update: { state, action in
            state.update(action)
        }, view: { $0.view }, subscriptions: { $0.subscriptions }, rootView: stackView, model: model)
    
    }
    
    
}

// ------------------------------------------  MAVB ------------------------------------------------
//暂时不做 直接绑定view 和model
extension ViewController {
    func mavbDidLoad() {
        
        
    }
    
    
   
}

// ------------------------------------------  Clean ------------------------------------------------
protocol CleanPresenterProtocol: class {
    var textFieldValue: String { get set }
}


class CleanUseCase {
    
    let model: Model
    
    var modelValue: String {
        get {
            return model.value
        }
        set {
            model.value = newValue
        }
    }
    
    weak var presenter: CleanPresenterProtocol?
    
    var observer: NSObjectProtocol?
    
    init(model: Model) {
        // use case 持有model
        
        self.model = model
        // model的变化通知到 use case  usecase 传给 presenter
        observer = NotificationCenter.default.addObserver(forName: Model.textDidChange, object: nil, queue: nil, using: { [weak self] n in
            self?.presenter?.textFieldValue = n.userInfo?[Model.textKey] as? String ?? ""
        })
    }
}


protocol CleanViewProtocol: class {
    
    var cleanTextFieldValue: String { get set }
}


class CleanPresenter: CleanPresenterProtocol {
    
    let useCase: CleanUseCase
    //持有view
    weak var view: CleanViewProtocol? {
        didSet {
            if let v = view {
                //model -> use case -> presenter -> view
                v.cleanTextFieldValue = textFieldValue
            }
        }
    }
    
    init(useCase: CleanUseCase) {
        
        //持有use cese
        self.useCase = useCase
        
        self.textFieldValue = useCase.modelValue
        
        //self 的presenter
        useCase.presenter = self
        
    }
    
    var textFieldValue: String {
        didSet {
            //传值给 view
            view?.cleanTextFieldValue = textFieldValue
        }
    }
    //传值给 use case
    func commit() {
        useCase.modelValue = view?.cleanTextFieldValue ?? ""
    }
}




extension ViewController: CleanViewProtocol {
   
    var cleanTextFieldValue: String {
        get {
            return cleanTextField.text ?? ""
        }
        set {
            cleanTextField.text = newValue
        }
    }
    // controller 持有 view 持有 usecase 持有 presenter
    
    func cleanDidLoad() {
        //初始化use case
        let useCase = CleanUseCase(model: model)
        
        //传给 presenter
        cleanPresenter = CleanPresenter(useCase: useCase)
        
        //presenter 持有 view
        cleanPresenter.view = self
    }
    
    @IBAction func  cleanButtonPressed() {
        cleanPresenter.commit()
    }
}
