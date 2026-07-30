import SwiftUI
import Charts

struct DashboardView: View {
    @Bindable var auth: AuthManager
    @State private var dashboard = DashboardManager()
    @State private var showDatePicker = false
    @AppStorage("isDarkMode") private var isDarkMode = true
    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color.black : Color.white).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Header Date Selector Pill
                        HStack {
                            VStack(alignment: .leading) {
                                Text("OVERVIEW")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary.opacity(0.6))
                                Text("Octopus Dashboard")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Button(action: { showDatePicker.toggle() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                    Text("Filter Date")
                                        .font(.footnote)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        if dashboard.isLoading {
                            ProgressView()
                                .tint(.primary)
                                .scaleEffect(1.5)
                                .padding(.top, 50)
                        } else if let error = dashboard.errorMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text(error)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                Button("Retry") {
                                    refreshData()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.teal)
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                            .padding()
                        } else if let data = dashboard.data {
                            
                            // 1. Primary Total Sales Glass Card
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Total Sales")
                                    .font(.subheadline)
                                    .foregroundColor(.primary.opacity(0.7))
                                
                                Text(formatCurrency(data.totalSales ?? 0))
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal)
                            
                            // 2. Sales Trend Chart (Monthly)
                            if let monthly = data.monthlySales, !monthly.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("Monthly Sales Trend")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Chart(monthly) { item in
                                        BarMark(
                                            x: .value("Month", item.monthLabel),
                                            y: .value("Sales", item.total ?? 0)
                                        )
                                        .foregroundStyle(Color.teal.gradient)
                                        .cornerRadius(6)
                                    }
                                    .frame(height: 180)
                                }
                                .padding(20)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                                .padding(.horizontal)
                            }
                            
                            // 3. Hourly Sales Peak Times Chart
                            if let hourly = data.hourlySales, !hourly.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("Hourly Peak Times")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Chart(hourly) { item in
                                        LineMark(
                                            x: .value("Hour", item.hourLabel),
                                            y: .value("Sales", item.total ?? 0)
                                        )
                                        .foregroundStyle(Color.indigo.gradient)
                                        .interpolationMethod(.catmullRom)
                                        
                                        AreaMark(
                                            x: .value("Hour", item.hourLabel),
                                            y: .value("Sales", item.total ?? 0)
                                        )
                                        .foregroundStyle(Color.indigo.opacity(0.3).gradient)
                                        .interpolationMethod(.catmullRom)
                                    }
                                    .frame(height: 150)
                                }
                                .padding(20)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                                .padding(.horizontal)
                            }
                            
                            // 4. Top Products List
                            if let products = data.topProducts, !products.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("Top Products")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    ForEach(products.prefix(5)) { item in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.productName ?? "Unknown")
                                                    .foregroundColor(.primary)
                                                    .fontWeight(.medium)
                                                Text("\(Int(item.quantity ?? 0)) sold")
                                                    .font(.caption)
                                                    .foregroundColor(.primary.opacity(0.6))
                                            }
                                            Spacer()
                                            Text(formatCurrency(item.total ?? 0))
                                                .foregroundColor(.teal)
                                                .fontWeight(.bold)
                                        }
                                        if item.id != products.prefix(5).last?.id {
                                            Divider()
                                                .background(Color.primary.opacity(0.1))
                                        }
                                    }
                                }
                                .padding(20)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                                .padding(.horizontal)
                            }
                            
                            // 5. Top Customers List
                            if let customers = data.topCustomers, !customers.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("Top Customers")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    ForEach(customers.prefix(5)) { item in
                                        HStack {
                                            Text(item.customerName ?? "Unknown")
                                                .foregroundColor(.primary)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(formatCurrency(item.total ?? 0))
                                                .foregroundColor(.indigo)
                                                .fontWeight(.bold)
                                        }
                                        if item.id != customers.prefix(5).last?.id {
                                            Divider()
                                                .background(Color.primary.opacity(0.1))
                                        }
                                    }
                                }
                                .padding(20)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
                .refreshable {
                    refreshData()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDatePicker) {
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Select Date Range")
                            .font(.headline)
                            .padding(.top)

                        // Predefined period quick-select
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Predefined period")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(datePresets) { preset in
                                    Button(action: { applyPreset(preset) }) {
                                        Text(preset.title)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color.primary.opacity(0.08))
                                            .foregroundColor(.primary)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }

                        Divider()

                        // Custom range
                        DatePicker("Start Date", selection: $dashboard.startDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $dashboard.endDate, displayedComponents: .date)

                        Button(action: {
                            showDatePicker = false
                            refreshData()
                        }) {
                            Text("Apply Filter")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.teal)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                refreshData()
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
    
    private func refreshData() {
        guard let token = auth.jwtToken else { return }
        Task {
            await dashboard.fetchDashboardData(apiBaseUrl: auth.apiBaseUrl, token: token)
        }
    }

    // MARK: - Date presets

    private struct DatePreset: Identifiable {
        let id = UUID()
        let title: String
        let range: (Calendar) -> (start: Date, end: Date)
    }

    // Sets the selected range from a preset, closes the sheet, and refreshes.
    private func applyPreset(_ preset: DatePreset) {
        let result = preset.range(Calendar.current)
        dashboard.startDate = result.start
        dashboard.endDate = result.end
        showDatePicker = false
        refreshData()
    }

    private var datePresets: [DatePreset] {
        // Helper: the full [start, end] of the period containing `date`.
        func fullPeriod(_ component: Calendar.Component, containing date: Date, _ cal: Calendar) -> (Date, Date) {
            let interval = cal.dateInterval(of: component, for: date) ?? DateInterval(start: date, duration: 0)
            return (interval.start, interval.end.addingTimeInterval(-1))
        }
        // Helper: from the start of the current period up to now.
        func periodToNow(_ component: Calendar.Component, _ cal: Calendar) -> (Date, Date) {
            let interval = cal.dateInterval(of: component, for: Date()) ?? DateInterval(start: Date(), duration: 0)
            return (interval.start, Date())
        }
        return [
            DatePreset(title: "Today") { cal in (cal.startOfDay(for: Date()), Date()) },
            DatePreset(title: "Yesterday") { cal in
                let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                return fullPeriod(.day, containing: yesterday, cal)
            },
            DatePreset(title: "This week") { cal in periodToNow(.weekOfYear, cal) },
            DatePreset(title: "Last week") { cal in
                let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
                return fullPeriod(.weekOfYear, containing: lastWeek, cal)
            },
            DatePreset(title: "This month") { cal in periodToNow(.month, cal) },
            DatePreset(title: "Last month") { cal in
                let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                return fullPeriod(.month, containing: lastMonth, cal)
            },
            DatePreset(title: "This year") { cal in periodToNow(.year, cal) },
            DatePreset(title: "Last Year") { cal in
                let lastYear = cal.date(byAdding: .year, value: -1, to: Date()) ?? Date()
                return fullPeriod(.year, containing: lastYear, cal)
            }
        ]
    }
    
    private func formatCurrency(_ value: Double) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            
            let formattedNumber = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
            
            return "\(formattedNumber) DH"
        }
}
