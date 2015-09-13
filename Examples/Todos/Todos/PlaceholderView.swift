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

class PlaceholderView: UIView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    setUp()
  }
  
  convenience init() {
    self.init(frame: CGRectZero)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
    setUp()
  }
  
  private var loadingIndicatorView: UIActivityIndicatorView!
  private var contentView: UIView!
  private var titleLabel: UILabel!
  private var messageLabel: UILabel!
  
  func setUp() {
    let textColor = UIColor(white: 172/255.0, alpha:1)
    
    translatesAutoresizingMaskIntoConstraints = false
    
    loadingIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    loadingIndicatorView.translatesAutoresizingMaskIntoConstraints = false
    loadingIndicatorView.color = UIColor.lightGrayColor()
    addSubview(loadingIndicatorView)
    
    contentView = UIView(frame: CGRectZero)
    contentView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(contentView)
    
    titleLabel = UILabel(frame: CGRectZero)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.textAlignment = .Center
    titleLabel.backgroundColor = nil
    titleLabel.opaque = false
    titleLabel.font = UIFont.systemFontOfSize(22)
    titleLabel.numberOfLines = 0_
    titleLabel.textColor = textColor
    contentView.addSubview(titleLabel)
    
    messageLabel = UILabel(frame: CGRectZero)
    messageLabel.translatesAutoresizingMaskIntoConstraints = false
    messageLabel.textAlignment = .Center
    messageLabel.backgroundColor = nil
    messageLabel.opaque = false
    messageLabel.font = UIFont.systemFontOfSize(14)
    messageLabel.numberOfLines = 0_
    messageLabel.textColor = textColor
    contentView.addSubview(messageLabel)
    
    addConstraint(NSLayoutConstraint(item: loadingIndicatorView, attribute: .CenterX, relatedBy: .Equal, toItem: self, attribute: .CenterX, multiplier: 1.0, constant: 0.0))
    addConstraint(NSLayoutConstraint(item: loadingIndicatorView, attribute: .CenterY, relatedBy: .Equal, toItem: self, attribute: .CenterY, multiplier: 1.0, constant: 0.0))
    
    addConstraint(NSLayoutConstraint(item: contentView, attribute: .CenterX, relatedBy: .Equal, toItem: self, attribute: .CenterX, multiplier: 1.0, constant: 0.0))
    addConstraint(NSLayoutConstraint(item: contentView, attribute: .CenterY, relatedBy: .Equal, toItem: self, attribute: .CenterY, multiplier: 1.0, constant: 0.0))
    
    let views = ["contentView": contentView, "titleLabel": titleLabel, "messageLabel": messageLabel]
    
    if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
      addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-(>=30)-[contentView(<=418)]-(>=30)-|", options: [], metrics: nil, views: views))
    } else {
      addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-30-[contentView]-30-|", options: [], metrics: nil, views: views))
    }
    
    addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[titleLabel]|", options: [], metrics: nil, views: views))
    addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[messageLabel]|", options: [], metrics: nil, views: views))
    addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[titleLabel]-15-[messageLabel]|", options: [], metrics: nil, views: views))
  }
  
  private var title: String? {
    didSet {
      titleLabel.text = title
    }
  }
  
  private var message: String? {
    didSet {
      messageLabel.text = message
    }
  }
  
  func showLoadingIndicator() {
    contentView.hidden = true
    loadingIndicatorView.startAnimating()
  }
  
  func hideLoadingIndicator() {
    contentView.hidden = false
    loadingIndicatorView.stopAnimating()
  }
  
  func showTitle(title: String?, message: String?) {
    hideLoadingIndicator()
    self.title = title
    self.message = message
  }
}
