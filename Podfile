source 'https://github.com/CocoaPods/Specs.git'

use_frameworks!

platform :ios, '7.0'

workspace 'Meteor'

xcodeproj 'Meteor'

podspec

link_with ['Meteor', 'Server Integration Tests']
  
target 'Unit Tests' do
  pod 'OCMock'
end

target 'Leaderboard', exclusive: true do
  xcodeproj 'Examples/Leaderboard/Leaderboard'
  pod 'Meteor', path: '.'
end

target 'Todos', exclusive: true do
  xcodeproj 'Examples/Todos/Todos'
  pod 'Meteor', path: '.'
end
