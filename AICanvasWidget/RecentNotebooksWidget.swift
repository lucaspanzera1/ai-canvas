import WidgetKit
import SwiftUI

struct RecentNotebooksEntry: TimelineEntry {
    let date: Date
    let notebooks: [WidgetNotebookSnapshot]
}

struct RecentNotebooksProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentNotebooksEntry {
        RecentNotebooksEntry(date: .now, notebooks: Self.sampleNotebooks)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentNotebooksEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentNotebooksEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> RecentNotebooksEntry {
        let notebooks = AICanvasAppGroup.load([WidgetNotebookSnapshot].self, forKey: AICanvasAppGroup.recentNotebooksKey) ?? []
        return RecentNotebooksEntry(date: .now, notebooks: notebooks)
    }

    static let sampleNotebooks: [WidgetNotebookSnapshot] = [
        WidgetNotebookSnapshot(id: UUID(), name: "Cálculo II", emoji: "📐", colorIndex: 0, lastModified: .now),
        WidgetNotebookSnapshot(id: UUID(), name: "Anotações de Física", emoji: "🧪", colorIndex: 1, lastModified: .now.addingTimeInterval(-3600)),
        WidgetNotebookSnapshot(id: UUID(), name: "Ideias", emoji: "✨", colorIndex: 2, lastModified: .now.addingTimeInterval(-7200)),
    ]
}


private let relativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
}()

struct RecentNotebooksWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RecentNotebooksEntry

    private var maxCount: Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 3
        default: return 5
        }
    }

    var body: some View {
        let notebooks = Array(entry.notebooks.prefix(maxCount))
        VStack(alignment: .leading, spacing: 10) {
            Label("Recentes", systemImage: "clock.arrow.circlepath")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if notebooks.isEmpty {
                Spacer(minLength: 0)
                Text("Abra o AI Canvas para ver seus cadernos aqui.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(notebooks) { notebook in
                    Link(destination: AICanvasDeepLink.notebookURL(id: notebook.id)) {
                        NotebookRow(notebook: notebook)
                    }
                }
                if family != .systemSmall { Spacer(minLength: 0) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Color(uiColor: .secondarySystemGroupedBackground), for: .widget)
    }
}

private struct NotebookRow: View {
    let notebook: WidgetNotebookSnapshot

    var body: some View {
        HStack(spacing: 10) {
            Text(notebook.emoji)
                .font(.system(size: 17))
                .grayscale(1)
                .frame(width: 32, height: 32)
                .overlay(Rectangle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(notebook.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text(relativeFormatter.localizedString(for: notebook.lastModified, relativeTo: .now))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

struct RecentNotebooksWidget: Widget {
    let kind = "RecentNotebooksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentNotebooksProvider()) { entry in
            RecentNotebooksWidgetView(entry: entry)
        }
        .configurationDisplayName("Cadernos Recentes")
        .description("Acesse rapidamente os cadernos que você editou por último.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    RecentNotebooksWidget()
} timeline: {
    RecentNotebooksEntry(date: .now, notebooks: RecentNotebooksProvider.sampleNotebooks)
}
