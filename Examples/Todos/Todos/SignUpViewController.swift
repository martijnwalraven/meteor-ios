// Copyright (c) 2014-2015 Martijn Walraven
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit
import CoreData
import Meteor

class SignUpViewController: UIViewController, UITextFieldDelegate {
  @IBOutlet weak var errorMessageLabel: UILabel!
  @IBOutlet weak var emailField: UITextField!
  @IBOutlet weak var passwordField: UITextField!
  @IBOutlet weak var passwordConfirmationField: UITextField!
  
  // MARK: View Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    
    errorMessageLabel.text = nil
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    
    emailField.becomeFirstResponder()
  }
  
  // MARK: UITextFieldDelegate
  
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    if textField == emailField {
      passwordField.becomeFirstResponder()
    } else if textField == passwordField {
      passwordConfirmationField.becomeFirstResponder()
    } else if textField == passwordConfirmationField {
      passwordConfirmationField.resignFirstResponder()
      signUp()
    }
    return false
  }
  
  // MARK: IBActions
  
  @IBAction func signUp() {
    errorMessageLabel.text = nil
    
    let email = emailField.text
    let password = passwordField.text
    let passwordConfirmation = passwordConfirmationField.text
    
    if email.isEmpty || password.isEmpty || passwordConfirmation.isEmpty {
      errorMessageLabel.text = "Email, password and password confirmation are required"
      return
    } else if password != passwordConfirmation {
      errorMessageLabel.text = "Password and password confirmation do not match"
      return
    }
    
    Meteor.signUpWithEmail(email, password: password) { (error) -> Void in
      if error != nil {
        self.errorMessageLabel.text = error.localizedFailureReason
      } else {
        self.performSegueWithIdentifier("Unwind", sender: self)
      }
    }
  }
}
