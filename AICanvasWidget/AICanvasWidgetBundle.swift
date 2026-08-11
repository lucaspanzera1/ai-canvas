import WidgetKit
import SwiftUI

@main
struct AICanvasWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentNotebooksWidget()
        PomodoroStatusWidget()
        QuickNewNotebookWidget()
    }
}
