source 'https://github.com/CocoaPods/Specs.git'

use_frameworks!

platform :ios, '7.0'

workspace 'Meteor'

xcodeproj 'Meteor'
link_with ['Meteor', 'UnitTests', 'ServerIntegrationTests']

podspec
  
target 'UnitTests' do
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
