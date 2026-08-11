import WidgetKit
import SwiftUI

struct QuickNewNotebookEntry: TimelineEntry {
    let date: Date
}

struct QuickNewNotebookProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickNewNotebookEntry {
        QuickNewNotebookEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickNewNotebookEntry) -> Void) {
        completion(QuickNewNotebookEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickNewNotebookEntry>) -> Void) {
        completion(Timeline(entries: [QuickNewNotebookEntry(date: .now)], policy: .never))
    }
}

struct QuickNewNotebookWidgetView: View {
    var body: some View {
        Link(destination: AICanvasDeepLink.newNotebookURL) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.tint)
                Spacer(minLength: 0)
                Text("Novo Caderno")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Criar e abrir")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .containerBackground(Color(uiColor: .secondarySystemGroupedBackground), for: .widget)
    }
}

struct QuickNewNotebookWidget: Widget {
    let kind = "QuickNewNotebookWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickNewNotebookProvider()) { _ in
            QuickNewNotebookWidgetView()
        }
        .configurationDisplayName("Novo Caderno")
        .description("Crie um caderno novo direto da tela de início.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    QuickNewNotebookWidget()
} timeline: {
    QuickNewNotebookEntry(date: .now)
}
