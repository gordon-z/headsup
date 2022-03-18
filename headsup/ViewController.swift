// #-code-snippet: navigation dependencies-swift
import MapboxMaps
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import Turf
import UIKit
import MQTTClient
import Foundation
import Numerics


var direction = [String]()
var coords = [Double]()
var currCoords = [Double]()

var DistanceNextInstruction: Double = 30.0
var DistancePointReached: Double = 15.0
var sentToBluetooth: Bool = false

let MQTT_HOST = "localhost" // or IP address e.g. "192.168.0.194"
let MQTT_PORT: UInt32 = 1883

//struct Coords {
//    let location: (latitude: Double, longitude: Double)
//}
//
//extension Coords {
//    init?(json: [String: Any]) {
//        guard let name = json["name"] as? String,
//              let latitude =
//    }
//}
// #-end-code-snippet: navigation dependencies-swift
class ViewController: UIViewController, CLLocationManagerDelegate {
    // #-code-snippet: navigation vc-variables-swift
    var navigationMapView: NavigationMapView!
    var navigationViewController: NavigationViewController!
    var routeOptions: NavigationRouteOptions?
    var routeResponse: RouteResponse?
    var startButton: UIButton!
    var navigation: RouteController!
    internal var mapView: MapView!
    var locationManager: CLLocationManager!
    var currentLocation: CLLocation?
    
    
    // #-end-code-snippet: navigation vc-variables-swift
    // #-code-snippet: navigation view-did-load-swift
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationMapView = NavigationMapView(frame: view.bounds)
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigationMapView)
        
        // By default `NavigationViewportDataSource` tracks location changes from `PassiveLocationDataSource`, to consume
        // raw locations `ViewportDataSourceType` should be set to `.raw`.
        let navigationViewportDataSource = NavigationViewportDataSource(navigationMapView.mapView, viewportDataSourceType: .raw)
        navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource
        
        // Allow the map to display the user's location
        navigationMapView.userLocationStyle = .puck2D()
        
        // Add a gesture recognizer to the map view
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        navigationMapView.addGestureRecognizer(longPress)
        
        // Add a button to start navigation
        displayStartButton()
        
        coords.append(0)
        coords.append(0)
        
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
        

//        print("navigation viewport: \(navigationViewportDataSource.))")
//        navigationMapView.mapboxMap.onNext(.mapLoaded) { [self]_ in
//                   self.locationUpdate(newLocation: navigationMapView.location.latestLocation!)
//               }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        defer { currentLocation = locations.last }
//        print("Current Location: \(String(locations.debugDescription))")
        
        let string = String(locations.debugDescription)
        let stringSplit = string.components(separatedBy: "<")
        let stringSplit2 = stringSplit[1].components(separatedBy: ">")
        var stringSplit3 = stringSplit2[0]
        for i in 0...stringSplit3.count-2 {
            let index = stringSplit3.index(stringSplit3.startIndex, offsetBy: i)
            if stringSplit3[index] == "+"{
                stringSplit3.remove(at: index)
            }
        }
        let stringSplit4 = stringSplit3.components(separatedBy: ",")
        currCoords.removeAll()
        for index in 0...(stringSplit4.count-1){
            currCoords.append((stringSplit4[index] as NSString).doubleValue)
        }
        print("currCoords: \(currCoords)")
        
        let latCurr = currCoords[0]/(180/(Double.pi))
        let longCurr = currCoords[1]/(180/(Double.pi))
        let latWay = coords[0]/(180/(Double.pi))
        let longWay = coords[1]/(180/(Double.pi))
        let Distance = 1000.0*1.609344*(3963.0*acos((sin(latCurr)*sin(latWay)+cos(latCurr)*cos(latWay)*cos(longWay - longCurr))))
        print("lat current: \(latCurr)")
        print("long current: \(longCurr)")
        print("lat waypoint: \(latWay)")
        print("long waypoint: \(longWay)")
        print("Distance (m): \(Distance)")
        
        if Distance < DistanceNextInstruction && sentToBluetooth == false {
//            Ideally only happens once
            print("Send to bluetooth")
            sentToBluetooth = true
        }
        if Distance < DistancePointReached {
//            Make sure only happens once
            coords.removeFirst()
            coords.removeFirst()
            direction.removeFirst()
            sentToBluetooth = false
        }
    }
    
//    func navigationViewController(_ navigationViewController: NavigationViewController, willArriveAt waypoint: Waypoint, after remainingTimeInterval: TimeInterval, distance: CLLocationDistance)
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        startButton.layer.cornerRadius = startButton.bounds.midY
        startButton.clipsToBounds = true
        startButton.setNeedsDisplay()
    }
    // #-end-code-snippet: navigation view-did-load-swift
    
       
    
    
    // #-code-snippet: navigation display-start-button-swift
    func displayStartButton() {
        startButton = UIButton()
        
        // Add a title and set the button's constraints
        startButton.setTitle("Start Navigation", for: .normal)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.backgroundColor = .blue
        startButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        startButton.addTarget(self, action: #selector(tappedButton(sender:)), for: .touchUpInside)
        startButton.isHidden = true
        view.addSubview(startButton)
        
        startButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        startButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        view.setNeedsLayout()
    }
    // #-end-code-snippet: navigation display-start-button-swift
    
    // #-code-snippet: navigation long-press-swift
    @objc func didLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }

        // Converts point where user did a long press to map coordinates
        let point = sender.location(in: navigationMapView)
        let coordinate = navigationMapView.mapView.mapboxMap.coordinate(for: point)

        if let origin = navigationMapView.mapView.location.latestLocation?.coordinate {
            // Calculate the route from the user's location to the set destination
            calculateRoute(from: origin, to: coordinate)
        } else {
            print("Failed to get user location, make sure to allow location access for this application.")
        }
    }
    // #-end-code-snippet: navigation long-press-swift
    
    // #-code-snippet: navigation tapped-button-swift
    // Present the navigation view controller when the start button is tapped
    @objc func tappedButton(sender: UIButton) {
        guard let routeResponse = routeResponse, let navigationRouteOptions = routeOptions else { return }
        navigationViewController = NavigationViewController(for: routeResponse, routeIndex: 0,
                                                                routeOptions: navigationRouteOptions)
        navigationViewController.modalPresentationStyle = .fullScreen
        present(navigationViewController, animated: true, completion: nil)
    }
    // #-end-code-snippet: navigation tapped-button-swift
    // #-code-snippet: navigation calculate-route-swift
    // Calculate route to be used for navigation
    func calculateRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        // Coordinate accuracy is how close the route must come to the waypoint in order to be considered viable. It is measured in meters. A negative value indicates that the route is viable regardless of how far the route is from the waypoint.
        let origin = Waypoint(coordinate: origin, coordinateAccuracy: -1, name: "Start")
        let destination = Waypoint(coordinate: destination, coordinateAccuracy: -1, name: "Finish")

        // Specify that the route is intended for cyclists avoiding traffic
        let routeOptions = NavigationRouteOptions(waypoints: [origin, destination], profileIdentifier: .cycling)
        
//        include steps of route
        print("routeOptions: \(routeOptions.includesSteps)")
        routeOptions.includesSteps = true
        // Generate the route object and draw it on the map
        
        
        Directions.shared.calculate(routeOptions) { [weak self] (session, result) in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let response):
                guard let route = response.routes?.first, let leg = route.legs.first, let strongSelf = self else {
                    return
                }
                
                strongSelf.routeResponse = response
                strongSelf.routeOptions = routeOptions
                // Show the start button
                strongSelf.startButton?.isHidden = false
                
                // Draw the route on the map after creating it
                strongSelf.drawRoute(route: route)
                
                // Show destination waypoint on the map
                strongSelf.navigationMapView.showWaypoints(on: route)
                print("Route via \(leg):")

                let distanceFormatter = LengthFormatter()
                let formattedDistance = distanceFormatter.string(fromMeters: route.distance)

                let travelTimeFormatter = DateComponentsFormatter()
                travelTimeFormatter.unitsStyle = .short
                let formattedTravelTime = travelTimeFormatter.string(from: route.expectedTravelTime)

                print("Distance: \(formattedDistance); ETA: \(formattedTravelTime!)")
                
                for step in leg.steps {
                    print("\(String(step.instructions))")
                    let formattedDistance = distanceFormatter.string(fromMeters: step.distance)
//                    print("— \(formattedDistance) —")
                    var stringSplit = String(step.instructions).components(separatedBy: " ")
                    for index in 0...(stringSplit.count-1){
                        if stringSplit[index] == "right" || stringSplit[index] == "left" || stringSplit[index] == "Right" || stringSplit[index] == "Left"{
                            direction.append((stringSplit[index]))
                            break
                        }
                        else if index == stringSplit.count-1{
                            direction.append("")
                        }
                    }
                    
                }
                direction.removeFirst()
                print(direction)
                let routeProgress = RouteProgress(route: route, options: routeOptions)
//                print("Route Progress: \(routeProgress.updateDistanceTraveled(with: ))")
//                print("Route Progress: \(routeProgress.upcomingStep)")

//                JSON Data of coordinates of waypoints along route
                
                guard let routeShape = route.shape, routeShape.coordinates.count > 0 else { return }
                guard let mapView = strongSelf.navigationMapView.mapView else { return }
                let sourceIdentifier = "routeStyle"
                // Convert the route’s coordinates into a linestring feature
                let feature = Feature(geometry: .lineString(LineString(routeShape.coordinates)))
                
                var geoJSONSource = GeoJSONSource()
                geoJSONSource.data = .feature(feature)
                try? mapView.mapboxMap.style.addSource(geoJSONSource, id: sourceIdentifier)
                // Customize the route line color and width
                var lineLayer = LineLayer(id: "routeLayer")
                lineLayer.source = sourceIdentifier
                lineLayer.lineColor = .constant(.init(UIColor(red: 0.1897518039, green: 0.3010634184, blue: 0.7994888425, alpha: 1.0)))
                lineLayer.lineWidth = .constant(3)
                
                // Add the style layer of the route line to the map
                try? mapView.mapboxMap.style.addLayer(lineLayer)
//                if let unwrapped = geoJSONSource.data{
//                    print("Else statement: \(unwrapped)")
//                }else{
//                    print("Failed to unwrap")
//                }
//                print("Else statement: \(String(geoJSONSource.data.debugDescription))")
                var string: String = String(geoJSONSource.data.debugDescription)
                let ignore: Set<Character> = ["!", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "/", ":", ";", "<", "=", ">", "?", "@", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "[", "]", "^", "_", "`", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "{", "|", "}", "~"]
                string.removeAll(where: {ignore.contains($0)})
                var stringSplit = string.components(separatedBy: " ")
                stringSplit.removeFirst(6)
                stringSplit.removeLast(4)
                for index in 0...(stringSplit.count/2-1){
                    stringSplit.remove(at: index)
                }
                coords.removeAll()
                for index in 2...(stringSplit.count-1){
                    coords.append((stringSplit[index] as NSString).doubleValue)
                }
                print("String Split: \(coords)")
                
            }
        }
    }

    // #-end-code-snippet: navigation calculate-route-swift
    // #-code-snippet: navigation draw-route-swift
    func drawRoute(route: Route) {
        guard let routeShape = route.shape, routeShape.coordinates.count > 0 else { return }
        guard let mapView = navigationMapView.mapView else { return }
        let sourceIdentifier = "routeStyle"
        // Convert the route’s coordinates into a linestring feature
        let feature = Feature(geometry: .lineString(LineString(routeShape.coordinates)))
        
        // If there's already a route line on the map, update its shape to the new route
        if mapView.mapboxMap.style.sourceExists(withId: sourceIdentifier) {
            try? mapView.mapboxMap.style.updateGeoJSONSource(withId: sourceIdentifier, geoJSON: .feature(feature))
            print("If statement")
        } else {
            // Convert the route’s coordinates into a lineString Feature and add the source of the route line to the map
//            var geoJSONSource = GeoJSONSource()
//            geoJSONSource.data = .feature(feature)
//            try? mapView.mapboxMap.style.addSource(geoJSONSource, id: sourceIdentifier)
//            // Customize the route line color and width
//            var lineLayer = LineLayer(id: "routeLayer")
//            lineLayer.source = sourceIdentifier
//            lineLayer.lineColor = .constant(.init(UIColor(red: 0.1897518039, green: 0.3010634184, blue: 0.7994888425, alpha: 1.0)))
//            lineLayer.lineWidth = .constant(3)
//
//            // Add the style layer of the route line to the map
//            try? mapView.mapboxMap.style.addLayer(lineLayer)
//            print("Else statement: \(geoJSONSource.data)")
        }
        
    }
    
    // #-end-code-snippet: navigation draw-route-swift
}

//extension ViewController: LocationPermissionsDelegate, LocationConsumer {
//    func locationUpdate(newLocation: Location) {
////        mapView.camera.fly(to: CameraOptions(center: newLocation.coordinate, zoom: 14.0), duration: 5.0)
//        print("New Location: \(newLocation)")
//    }
//}
