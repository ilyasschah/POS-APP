import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    // 1. Placeholder for when the widget is loading or shown in the widget gallery
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), totalSales: 0.0)
    }

    // 2. Snapshot provides a quick preview
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), totalSales: 1250.75)
        completion(entry)
    }

    // 3. Timeline fetches the real data from our shared App Group
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
            // Updated exact suiteName
            let sharedDefaults = UserDefaults(suiteName: "group.com.futur3.ownerapp")
            let sales = sharedDefaults?.double(forKey: "lastTotalSales") ?? 0.0
            
            let entry = SimpleEntry(date: Date(), totalSales: sales)
            let timeline = Timeline(entries: [entry], policy: .never)
            completion(timeline)
        }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let totalSales: Double
}

struct OwnerWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.teal)
                Text("Total Sales")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            
            Text(formatCurrency(entry.totalSales))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5) // Shrinks if the number is too big
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(Color(UIColor.systemBackground).opacity(0.8), for: .widget)
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

@main
struct OwnerWidget: Widget {
    let kind: String = "OwnerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            OwnerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Octopus Dashboard")
        .description("Quickly view your last known total sales.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
