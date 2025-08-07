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
                    Annotation("", coordinate: userCoordinate) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundStyle(.yellow)
                            .background(.white)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                }
                // Маршрут пробежки
                if viewModel.routeCoordinates.count > 1 {
                    MapPolyline(coordinates: viewModel.routeCoordinates)
                        .stroke(.yellow, lineWidth: 6.0)
                }
            }
            .mapStyle(.standard)
            .mapControlVisibility(.visible)
            .ignoresSafeArea()

            if !viewModel.isRunning {
                VStack {
                    HStack {
                        Button(action: {
                            print("Back pressed") // Заглушка для действия кнопки
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .padding()
                                .background(.white.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.leading, 20)
            }

            // Панель с метками и кнопками
            VStack(spacing: 20) {
                // Метки для времени, дистанции и калорий
                VStack(spacing: 10) {
                    Text("⏱️ Время: \(viewModel.formattedTime)")
                        .font(.title2)
                        .foregroundStyle(.black)
                    Text("👣 Дистанция: \(String(format: "%.0f", viewModel.totalDistance / 1000)) км")
                        .font(.title2)
                        .foregroundStyle(.black)
                    Text("🔥 Калории: \(String(format: "%.0f", viewModel.calories)) ккал")
                        .font(.title2)
                        .foregroundStyle(.black)

                }
                .padding()
                .background(.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 5)

                // Кнопки управления
                if !viewModel.isRunning {
                    // Только кнопка "Старт" до начала пробежки
                    Button(action: {
                        viewModel.startRun()
                    }) {
                        Text("Старт")
                            .font(.title3)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)
                } else {
                    // Кнопки "Пауза"/"Продолжить" и "Завершить" во время пробежки
                    HStack(spacing: 10) {
                        Button(action: {
                            viewModel.pauseRun()
                        }) {
                            Text(viewModel.isPaused ? "Продолжить" : "Пауза")
                                .font(.title3)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(viewModel.isPaused ? .green : .cyan)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button(action: {
                            viewModel.stopRun()
                        }) {
                            Text("Завершить")
                                .font(.title3)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.red)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            viewModel.requestPermissions()
        }
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
        DispatchQueue.main.async { [weak self] in
            self?.currentUserCoordinate = newLocation.coordinate
        }

        // Обновляем маршрут и дистанцию только во время активной пробежки
        if isRunning && !isPaused {
            self.locations.append(newLocation)
            DispatchQueue.main.async { [weak self] in
                self?.routeCoordinates = self?.locations.map { $0.coordinate } ?? []

                // Обновление дистанции
                if let locations = self?.locations, locations.count > 1 {
                    let lastLocation = locations[locations.count - 2]
                    self?.totalDistance += newLocation.distance(from: lastLocation)
                }
            }
        }

        // Обновление позиции камеры карты для следования за пользователем
        DispatchQueue.main.async { [weak self] in
            self?.cameraPosition = .region(
                MKCoordinateRegion(
                    center: newLocation.coordinate,
                    latitudinalMeters: 500,
                    longitudinalMeters: 500
                )
            )
        }
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
