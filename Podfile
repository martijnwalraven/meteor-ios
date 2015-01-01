source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '7.0'
use_frameworks!

workspace 'Meteor'
xcodeproj 'Tests/Meteor Tests'
  
target 'MeteorUnitTests' do
  pod 'Meteor', path: '.'
  pod 'OCMock'
end

target 'MeteorServerIntegrationTests' do
  pod 'Meteor', path: '.'
end

target 'Leaderboard' do
  xcodeproj 'Examples/Leaderboard/Leaderboard'
  pod 'Meteor', path: '.'
end

target 'Todos' do
  xcodeproj 'Examples/Todos/Todos'
  pod 'Meteor', path: '.'
end
