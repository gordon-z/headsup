// mosquitto_sub -t "test/message" -h test.mosquitto.org
// mosquitto_pub -h test.mosquitto.org -t "test/message" -m "fall"
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
import ContactsUI
import Contacts

var direction = [String]()
var coords = [Double]()
var currCoords = [Double]()

var DistanceNextInstruction: Double = 50.0
var DistancePointReached: Double = 15.0
var sentToBluetooth: Bool = false
var directionBit: Int = 0
var slopeDiff: Double = 1

var contactNumber: String = ""

//let MQTT_HOST = "localhost" // or IP address e.g. "192.168.0.194"
let MQTT_HOST = "test.mosquitto.org"
let MQTT_PORT: UInt32 = 1883


class ViewController: UIViewController, CLLocationManagerDelegate, CNContactPickerDelegate {
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
    private var transport = MQTTCFSocketTransport()
    fileprivate var session = MQTTSession()
    fileprivate var completion: (()->())?
    
    // #-end-code-snippet: navigation vc-variables-swift
    // #-code-snippet: navigation view-did-load-swift
    override func viewDidLoad() {
        super.viewDidLoad()

        self.session?.delegate = self
        self.transport.host = MQTT_HOST
        self.transport.port = MQTT_PORT
        session?.transport = transport
        session?.connect()
//        subscribe()
        
        
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
        direction.append("Ben")
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
        
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .denied || status == .restricted {
            presentSettingsActionSheet()
            return
        }

        // open it
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            guard granted else {
                DispatchQueue.main.async {
                    self.presentSettingsActionSheet()
                }
                return
            }

            // get the contacts
            var contacts = [CNContact]()
            let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as NSString, CNContactFormatter.descriptorForRequiredKeys(for: .fullName)])
            do {
                try store.enumerateContacts(with: request) { contact, stop in
                    contacts.append(contact)
                }
            } catch {
                print(error)
            }

            // do something with the contacts array (e.g. print the names)
            let formatter = CNContactFormatter()
            formatter.style = .fullName
            
            self.presentContactPicker()
        }

    }
    
    private func publishMessage(_ message: String, onTopic topic: String) {
        session?.publishData(message.data(using: .utf8, allowLossyConversion: false), onTopic: topic, retain: false, qos: .exactlyOnce)
    }
    
    func presentContactPicker() {
        let contactPickerVC = CNContactPickerViewController()
        contactPickerVC.delegate = self
        present(contactPickerVC, animated: true)
    }
    
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        contactNumber = (contact.phoneNumbers.first?.value.stringValue)!
        contactNumber = contactNumber.components(separatedBy: [" ", "-", "(", ")"]).joined()
        print("Contact Number: \(contactNumber)")
    }

    
    private func subscribe() {
        self.session?.subscribe(toTopic: "test/headsup", at: .exactlyOnce) { error, result in
            print("subscribe result error \(String(describing: error)) result \(result!)")
        }
    }
    
    func presentSettingsActionSheet() {
        let alert = UIAlertController(title: "Permission to Contacts", message: "This app needs access to contacts in order to ...", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Go to Settings", style: .default) { _ in
            let url = URL(string: UIApplication.openSettingsURLString)!
            UIApplication.shared.open(url)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        defer { currentLocation = locations.last }
        
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
//            startedNavigation = true
            if (direction[0] == "right" || direction[0] == "Right"){
                directionBit = 1
            }
            else {
                directionBit = 0
            }
            publishMessage(String(directionBit), onTopic: "test/headsup")
        }
        if Distance < DistancePointReached {
//            Make sure only happens once
            coords.removeFirst()
            coords.removeFirst()
            direction.removeFirst()
            sentToBluetooth = false
        }
        
    }
    
    
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
                
                direction.removeAll()
                
                for step in leg.steps {
                    print("\(String(step.instructions))")
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
                    print("String Index: \(stringSplit)")
                    
                }
         


//                JSON Data of coordinates of waypoints along route
                
                guard let routeShape = route.shape, routeShape.coordinates.count > 0 else { return }
                
                // Convert the route’s coordinates into a linestring feature
                let feature = Feature(geometry: .lineString(LineString(routeShape.coordinates)))
                
                var geoJSONSource = GeoJSONSource()
                geoJSONSource.data = .feature(feature)
                 
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
                
                var origin = [Double]()
                origin.append((stringSplit[0] as NSString).doubleValue)
                origin.append((stringSplit[1] as NSString).doubleValue)
                
                for index in 2...(stringSplit.count-1){
                    coords.append((stringSplit[index] as NSString).doubleValue)
                }
                
                print("original String Split: \(coords)")
                
                                
                var baseslope: Double
                var endslope: Double
                var basepointLat: Double
                var basepointLong: Double
                var endpointLat: Double
                var endpointLong: Double
                var coordsRemove = [Int]()

                
                basepointLat = coords[0]
                basepointLong = coords[1]
                endpointLat = coords[2]
                endpointLong = coords[3]
                baseslope = (endpointLong - basepointLong)/(endpointLat - basepointLat)
                for i in stride(from: 0, to: coords.count-3, by: 2) {
//                    basepointLat = coords[i]
//                    basepointLong = coords[i+1]
                    endpointLat = coords[i+2]
                    endpointLong = coords[i+3]
                    
                    endslope = (endpointLong - basepointLong)/(endpointLat - basepointLat)
                    if (abs(endslope - baseslope) > slopeDiff || i == 0) {
                        basepointLat = coords[i]
                        basepointLong = coords[i+1]
                        baseslope = (endpointLong - basepointLong)/(endpointLat - basepointLat)
                    }
                    else {
//                        coords.remove(at: i)
//                        coords.remove(at: i)
                        coordsRemove.append(i)
                        coordsRemove.append(i+1)
                    }
                    
                    print("base slope: \(baseslope)")
                }
                
                let originASlope = (coords[1] - origin[1])/(coords[0] - origin[0])
                let ABSlope = (coords[3] - coords[1])/(coords[2] - coords[0])
                // If there is a first turn between origin A B, remove
                if (abs(ABSlope - originASlope) > slopeDiff){
                    direction.removeFirst()
                }
                
                print("Directions: \(direction)")
                
                for i in stride(from: coordsRemove.count-1, through: 0, by: -1) {
                    coords.remove(at: coordsRemove[i])
                }
                
                
               

                
                print("String Split: \(coords)")
                
                
            }
        }
        subscribe()
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
        } else {
            // Convert the route’s coordinates into a lineString Feature and add the source of the route line to the map
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
        }
        
    }
    
    // #-end-code-snippet: navigation draw-route-swift
}

extension ViewController: MQTTSessionManagerDelegate, MQTTSessionDelegate {

    func newMessage(_ session: MQTTSession!, data: Data!, onTopic topic: String!, qos: MQTTQosLevel, retained: Bool, mid: UInt32) {
        
        if let msg = String(data: data, encoding: .utf8) {
            print("topic \(topic!), msg \(msg)")
            // create the alert
            
            if msg == "fall"{
               
                if let phoneCallURL = URL(string: "tel://\(contactNumber)") {

                    let application:UIApplication = UIApplication.shared
                    if (application.canOpenURL(phoneCallURL)) {
                        application.open(phoneCallURL, options: [:], completionHandler: nil)
                    }
                }
            }
            
        }
    }

    func messageDelivered(_ session: MQTTSession, msgID msgId: UInt16) {
        print("delivered")
        DispatchQueue.main.async {
            self.completion?()
        }
    }
}
