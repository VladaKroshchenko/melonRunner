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
            // Карта с кастомной аннотацией пользователя и маршрутом
            Map(position: $viewModel.cameraPosition) {
                // Кастомная аннотация для текущей геопозиции пользователя
                if let userCoordinate = viewModel.currentUserCoordinate {
                    Annotation("User", coordinate: userCoordinate) {
                        Image(systemName: "arrowtriangle.up.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundStyle(.red)
                            .background(.white)
                            .clipShape(Circle())
                    }
                }
            }
            .mapStyle(.standard)
            .mapControlVisibility(.visible)
            .overlay(
                viewModel.routeCoordinates.count > 1 ? MapRouteView(coordinates: viewModel.routeCoordinates) : nil
            )
            .ignoresSafeArea()

            // Панель с метками и кнопками
            VStack(spacing: 20) {
                // Метки для времени, дистанции и калорий
                VStack(spacing: 10) {
                    Text("Время: \(viewModel.formattedTime)")
                        .font(.title2)
                        .foregroundStyle(.black)
                    Text("Дистанция: \(String(format: "%.2f", viewModel.totalDistance / 1000)) км")
                        .font(.title2)
                        .foregroundStyle(.black)
                    Text("Калории: \(String(format: "%.0f", viewModel.calories)) ккал")
                        .font(.title2)
                        .foregroundStyle(.black)
                }
                .padding()
                .background(.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 5)

                // Кнопки управления
                HStack(spacing: 10) {
                    // Кнопка Старт/Пауза/Продолжить
                    Button(action: {
                        if viewModel.isRunning {
                            viewModel.pauseRun()
                        } else {
                            viewModel.startRun()
                        }
                    }) {
                        Text(viewModel.isRunning ? (viewModel.isPaused ? "Продолжить" : "Пауза") : "Старт")
                            .font(.title3)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(viewModel.isRunning && !viewModel.isPaused ? .blue : .green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(false)

                    // Кнопка Завершить
                    Button(action: {
                        viewModel.stopRun()
                    }) {
                        Text("Завершить")
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

// Кастомный View для маршрута
struct MapRouteView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = false // Отключаем стандартный маркер
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        uiView.addOverlay(polyline)
        uiView.delegate = context.coordinator
        // Устанавливаем регион карты для отображения всего маршрута
        if !coordinates.isEmpty {
            let region = MKCoordinateRegion(coordinates)
            uiView.setRegion(region, animated: true)
        }
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

// Расширение для создания региона карты из координат
extension MKCoordinateRegion {
    init(_ coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            self.init(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            return
        }

        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3, // Увеличиваем на 30% для отступов
            longitudeDelta: (maxLon - minLon) * 1.3
        )
        self.init(center: center, span: span)
    }
}

// ViewModel для управления логикой
class RunningViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @Published var locations: [CLLocation] = []
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var currentUserCoordinate: CLLocationCoordinate2D? // Для кастомной аннотации
    @Published var totalDistance: Double = 0.0
    @Published var formattedTime: String = "00:00:00"
    @Published var calories: Double = 0.0
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false

    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private var startTime: Date?
    private var pauseTime: Date?
    private var accumulatedTime: TimeInterval = 0.0
    private var timer: Timer?
    private var calorieQuery: HKStatisticsCollectionQuery?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
    }

    func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
        // Начинаем обновление местоположения сразу после запроса разрешений
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }

        guard HKHealthStore.isHealthDataAvailable() else { return }
        let typesToRead: Set = [HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!]
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if !success {
                print("Ошибка авторизации HealthKit: \(error?.localizedDescription ?? "Неизвестная ошибка")")
            }
        }
    }

    func startRun() {
        isRunning = true
        isPaused = false
        startTime = Date()
        accumulatedTime = 0.0
        locations.removeAll()
        routeCoordinates.removeAll()
        totalDistance = 0.0
        calories = 0.0
        formattedTime = "00:00:00"
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        startCalorieUpdates()
    }

    func pauseRun() {
        isPaused.toggle()
        if isPaused {
            timer?.invalidate()
            pauseTime = Date()
            stopCalorieUpdates()
        } else {
            guard let pauseTime = pauseTime else { return }
            accumulatedTime += pauseTime.timeIntervalSince(startTime ?? pauseTime)
            startTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateTimer()
            }
            startCalorieUpdates()
        }
    }

    func stopRun() {
        isRunning = false
        isPaused = false
        timer?.invalidate()
        stopCalorieUpdates()
        fetchCalories() // Финальный запрос для точности
    }

    private func updateTimer() {
        guard let startTime = startTime else { return }
        let currentTime = accumulatedTime + Date().timeIntervalSince(startTime)
        let hours = Int(currentTime) / 3600
        let minutes = (Int(currentTime) % 3600) / 60
        let seconds = Int(currentTime) % 60
        formattedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func startCalorieUpdates() {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        guard let startTime = startTime else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: nil, options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startTime,
            intervalComponents: DateComponents(second: 10) // Обновление каждые 10 секунд
        )

        query.initialResultsHandler = { [weak self] query, collection, error in
            self?.updateCalories(from: collection)
        }

        query.statisticsUpdateHandler = { [weak self] query, statistics, collection, error in
            self?.updateCalories(from: collection)
        }

        healthStore.execute(query)
        calorieQuery = query
    }

    private func updateCalories(from collection: HKStatisticsCollection?) {
        guard let collection = collection, let startTime = startTime else { return }
        let now = Date()
        // Суммируем калории за все интервалы от startTime до now
        var totalCalories: Double = 0.0
        collection.enumerateStatistics(from: startTime, to: now) { statistics, _ in
            if let sum = statistics.sumQuantity() {
                totalCalories += sum.doubleValue(for: HKUnit.kilocalorie())
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.calories = totalCalories
        }
    }

    private func stopCalorieUpdates() {
        if let query = calorieQuery {
            healthStore.stop(query)
            calorieQuery = nil
        }
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
        guard let newLocation = locations.last else { return }

        // Обновляем текущую позицию пользователя для отображения стрелки
        self.currentUserCoordinate = newLocation.coordinate

        // Обновляем маршрут и дистанцию только во время активной пробежки
        if isRunning && !isPaused {
            self.locations.append(newLocation)
            self.routeCoordinates = self.locations.map { $0.coordinate }

            // Обновление дистанции
            if self.locations.count > 1 {
                let lastLocation = self.locations[self.locations.count - 2]
                totalDistance += newLocation.distance(from: lastLocation)
            }
        }

        // Обновление позиции камеры карты для следования за пользователем
        cameraPosition = .region(
            MKCoordinateRegion(
                center: newLocation.coordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Ошибка геолокации: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}

// Превью для SwiftUI
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
