//
//  ViewController.swift
//  TryMapKit
//
//  Created by Tirth Shah on 27/06/25.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController {
    
    //MARK: - IBOutlet
    @IBOutlet weak var Mapkit: MKMapView!
    @IBOutlet weak var searchBarMap: UISearchBar!
    @IBOutlet weak var mytableview: UITableView!
    
    //MARK: - Variable
    var centerPin: MKPointAnnotation?
    let geocoder = CLGeocoder()
    let loactionmanager = CLLocationManager()
    let fixedCoordinate = CLLocationCoordinate2D(latitude: 23.01250, longitude: 72.51442)
    var searchResualt = [MKMapItem]()
    
    //MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        loactionmanager.requestWhenInUseAuthorization()
        Mapkit.delegate = self
        searchBarMap.delegate = self
        setuptableview()
        mytableview.isHidden = true
        
        let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        let region = MKCoordinateRegion(center: fixedCoordinate, span: span)
        Mapkit.setRegion(region, animated: true)
        
        let fixedAnnotation = MKPointAnnotation()
        fixedAnnotation.coordinate = fixedCoordinate
        fixedAnnotation.title = "Fixed Location"
        Mapkit.addAnnotation(fixedAnnotation)
        
        let annotation = MKPointAnnotation()
        annotation.title = "Selected Location"
        Mapkit.addAnnotation(annotation)
        centerPin = annotation
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        Mapkit.addGestureRecognizer(tapGesture)
    }
    
    //MARK: - Function
    func setuptableview() {
        mytableview.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        self.mytableview.dataSource = self
        self.mytableview.delegate = self
    }
    
    @objc func handleMapTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let point = gestureRecognizer.location(in: Mapkit)
        let coordinate = Mapkit.convert(point, toCoordinateFrom: Mapkit)
        updatePinAndRoute(to: coordinate)
    }
    
    func updatePinAndRoute(to coordinate: CLLocationCoordinate2D) {
        centerPin?.coordinate = coordinate
        geocoder.cancelGeocode()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                print("Reverse geocoding error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            let name = placemark.name ?? ""
            let city = placemark.locality ?? ""
            let state = placemark.administrativeArea ?? ""
            let country = placemark.country ?? ""
            print("PlaceName: \(name), City: \(city), State: \(state), Country: \(country)")
            self?.centerPin?.title = name
        }
        drawRoute(from: fixedCoordinate, to: coordinate)
    }
    
    func drawRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) {
        Mapkit.removeOverlays(Mapkit.overlays)
        
        let startPlacemark = MKPlacemark(coordinate: start)
        let endPlacemark = MKPlacemark(coordinate: end)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: startPlacemark)
        request.destination = MKMapItem(placemark: endPlacemark)
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let route = response?.routes.first, error == nil else {
                print("Route error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            self?.Mapkit.addOverlay(route.polyline)
            self?.Mapkit.setVisibleMapRect(
                route.polyline.boundingMapRect,
                edgePadding: UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30),
                animated: true
            )
        }
    }
}

//MARK: - MapKit Delegate
extension ViewController : MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 5
            return renderer
        }
        return MKOverlayRenderer()
    }
}

//MARK: - UITableView Delegate & DataSource
extension ViewController : UITableViewDataSource,UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        searchResualt.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = searchResualt[indexPath.row]
        let cell = mytableview.dequeueReusableCell(withIdentifier: "cell")
        cell?.textLabel?.text = item.name
        return cell!
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = searchResualt[indexPath.row]
        searchBarMap.text = item.name
        tableView.deselectRow(at: indexPath, animated: true)
        if let coordinate = item.placemark.location?.coordinate {
            updatePinAndRoute(to: coordinate)
            mytableview.isHidden = true
        }
    }
}

//MARK: - Search BAR Delegate
extension ViewController : UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard !searchText.isEmpty else {
            searchResualt.removeAll()
            mytableview.reloadData()
            mytableview.isHidden = true
            return
        }
        mytableview.isHidden = false
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = Mapkit.region
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let response = response, error == nil else {
                print("Search error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            self?.searchResualt = response.mapItems
            self?.mytableview.reloadData()
        }
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
