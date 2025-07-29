//
//  ContentView.swift
//  melonRunner
//
//  Created by Kroshchenko Vlada on 29.07.2025.
//

import SwiftUI
import MapKit
import CoreLocation
import HealthKit

struct ContentView: View {
    @StateObject private var viewModel = RunningViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map with modern initializer
            Map(position: $viewModel.cameraPosition) {
                UserAnnotation() // Shows the user's location
            }
            .mapStyle(.standard)
            .overlay(
                viewModel.routeCoordinates.count > 1 ? MapRouteView(coordinates: viewModel.routeCoordinates) : nil
            )
            .ignoresSafeArea()

            // Panel with labels and buttons
            VStack(spacing: 20) {
                // Labels for time, distance, and calories
                VStack(spacing: 10) {
                    Text("Time: \(viewModel.formattedTime)")
                        .font(.title2)
                        .foregroundStyle(.black)
                    Text("Distance: \(String(format: "%.2f", viewModel.totalDistance / 1000)) km")
                        .font(.title2)
                        .foregroundStyle(.black)
                    Text("Calories: \(String(format: "%.0f", viewModel.calories)) kcal")
                        .font(.title2)
                        .foregroundStyle(.black)
                }
                .padding()
                .background(.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 5)

                // Control buttons
                HStack(spacing: 10) {
                    Button(action: {
                        viewModel.startRun()
                    }) {
                        Text("Start")
                            .font(.title3)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(viewModel.isRunning ? .gray : .green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(viewModel.isRunning)

                    Button(action: {
                        viewModel.pauseRun()
                    }) {
                        Text(viewModel.isPaused ? "Resume" : "Pause")
                            .font(.title3)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(viewModel.isRunning ? .blue : .gray)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!viewModel.isRunning)

                    Button(action: {
                        viewModel.stopRun()
                    }) {
                        Text("Stop")
                            .font(.title3)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(viewModel.isRunning ? .red : .gray)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!viewModel.isRunning)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            viewModel.requestPermissions()
        }
    }
}

// Custom View for the route
struct MapRouteView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        uiView.addOverlay(polyline)
        uiView.delegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 4.0
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}

// ViewModel for managing logic
class RunningViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @Published var locations: [CLLocation] = []
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var totalDistance: Double = 0.0
    @Published var formattedTime: String = "00:00:00"
    @Published var calories: Double = 0.0
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false

    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private var startTime: Date?
    private var timer: Timer?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
    }

    func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()

        guard HKHealthStore.isHealthDataAvailable() else { return }
        let typesToRead: Set = [HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!]
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if !success {
                print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    func startRun() {
        isRunning = true
        isPaused = false
        startTime = Date()
        locations.removeAll()
        routeCoordinates.removeAll()
        totalDistance = 0.0
        calories = 0.0
        formattedTime = "00:00:00"
        locationManager.startUpdatingLocation()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }

    func pauseRun() {
        isPaused.toggle()
        if isPaused {
            locationManager.stopUpdatingLocation()
            timer?.invalidate()
        } else {
            locationManager.startUpdatingLocation()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateTimer()
            }
        }
    }

    func stopRun() {
        isRunning = false
        isPaused = false
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        fetchCalories()
    }

    private func updateTimer() {
        guard let startTime = startTime else { return }
        let currentTime = Date().timeIntervalSince(startTime)
        let hours = Int(currentTime) / 3600
        let minutes = (Int(currentTime) % 3600) / 60
        let seconds = Int(currentTime) % 60
        formattedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func fetchCalories() {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let now = Date()
        let startOfRun = startTime ?? now
        let predicate = HKQuery.predicateForSamples(withStart: startOfRun, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            if let sum = result?.sumQuantity() {
                let calories = sum.doubleValue(for: HKUnit.kilocalorie())
                DispatchQueue.main.async {
                    self?.calories = calories
                }
            }
        }
        healthStore.execute(query)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRunning, !isPaused, let newLocation = locations.last else { return }
        self.locations.append(newLocation)
        self.routeCoordinates = self.locations.map { $0.coordinate }

        // Update distance
        if self.locations.count > 1 {
            let lastLocation = self.locations[self.locations.count - 2]
            totalDistance += newLocation.distance(from: lastLocation)
        }

        // Update map camera
        cameraPosition = .region(
            MKCoordinateRegion(
                center: newLocation.coordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

// Preview for SwiftUI
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
