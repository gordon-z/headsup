# headsup

To build app on iOS device, open headsup workspace in XCode and connect iOS device. 

Ensure you have the necessary certificates to deploy apps and modify the Team, Bundle Identifier, and Signing Certificate of the project and targets with your personal versions. 

Ensure you have the correct packages and versions of MapboxMaps, MapboxNavigation, and swift-numerics. This can be done with Swift Package Manager.

- MapboxMaps, Version 10.2.0, https://github.com/mapbox/mapbox-maps-ios.git
- MapboxNavigation, Version 2.2.0, https://github.com/mapbox/mapbox-navigation-ios.git
- swift-numerics, Version 1.0.0 - Next Major, https://github.com/apple/swift-numerics.git

Ensure that your podfile has the line 
```
pod 'MQTTClient'
```

Generate Mapbox public and secret API tokens. Follow this tutorial: https://docs.mapbox.com/ios/maps/guides/install/

You should be able to build your app on any iOS device or on the simulator now!
