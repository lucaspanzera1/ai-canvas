import SwiftUI

// MARK: - Graph Node Model

enum GraphNodeKind {
    case folder(Folder)
    case notebook(Notebook)
}

final class GraphNode: Identifiable {
    let id: UUID
    let kind: GraphNodeKind
    var position: CGPoint
    var velocity: CGVector = .zero
    var isDragging = false
    var dragOrigin: CGPoint = .zero
    var connectionCount = 0

    init(id: UUID, kind: GraphNodeKind, position: CGPoint) {
        self.id = id
        self.kind = kind
        self.position = position
    }

    var isFolder: Bool {
        if case .folder = kind { return true }
        return false
    }

    var displayName: String {
        switch kind {
        case .folder(let f): return f.name
        case .notebook(let n): return n.name
        }
    }

    var emoji: String {
        switch kind {
        case .folder(let f): return f.emoji
        case .notebook(let n): return n.emoji
        }
    }

    var colorIndex: Int {
        switch kind {
        case .folder(let f): return f.colorIndex
        case .notebook(let n): return n.colorIndex
        }
    }
}

struct GraphEdge {
    let a: UUID
    let b: UUID
}

// MARK: - Force-Directed Simulation Engine

@MainActor
final class GraphEngine: ObservableObject {
    @Published private(set) var tick: Int = 0

    private(set) var nodes: [GraphNode] = []
    private(set) var edges: [GraphEdge] = []
    private var nodesById: [UUID: GraphNode] = [:]
    private var indexById: [UUID: Int] = [:]

    let worldSize = CGSize(width: 1400, height: 1400)

    private let idealLength: CGFloat = 95
    private let repulsion: CGFloat = 7000
    private let springStrength: CGFloat = 0.02
    private let centerPull: CGFloat = 0.0025
    private let damping: CGFloat = 0.82

    private var timer: Timer?
    private var settledFrames = 0

    func node(for id: UUID) -> GraphNode? {
        nodesById[id]
    }

    func build(folders: [Folder], notebooks: [Notebook]) {
        let previous = nodesById
        let center = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)

        func startingPosition() -> CGPoint {
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let radius = CGFloat.random(in: 40...260)
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }

        var newNodes: [GraphNode] = []
        newNodes.reserveCapacity(folders.count + notebooks.count)

        for folder in folders {
            let pos = previous[folder.id]?.position ?? startingPosition()
            let node = GraphNode(id: folder.id, kind: .folder(folder), position: pos)
            node.velocity = previous[folder.id]?.velocity ?? .zero
            newNodes.append(node)
        }
        for notebook in notebooks {
            let pos = previous[notebook.id]?.position ?? startingPosition()
            let node = GraphNode(id: notebook.id, kind: .notebook(notebook), position: pos)
            node.velocity = previous[notebook.id]?.velocity ?? .zero
            newNodes.append(node)
        }

        var newEdges: [GraphEdge] = []
        for folder in folders {
            if let parentId = folder.parentFolderId {
                newEdges.append(GraphEdge(a: folder.id, b: parentId))
            }
        }
        for notebook in notebooks {
            if let folderId = notebook.folderId {
                newEdges.append(GraphEdge(a: notebook.id, b: folderId))
            }
        }

        nodes = newNodes
        edges = newEdges
        nodesById = Dictionary(uniqueKeysWithValues: newNodes.map { ($0.id, $0) })
        indexById = Dictionary(uniqueKeysWithValues: newNodes.enumerated().map { ($1.id, $0) })

        var counts: [UUID: Int] = [:]
        for edge in edges {
            counts[edge.a, default: 0] += 1
            counts[edge.b, default: 0] += 1
        }
        for node in nodes {
            node.connectionCount = counts[node.id] ?? 0
        }

        settledFrames = 0
        start()
    }

    func wake() {
        settledFrames = 0
        start()
    }

    private func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.step() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func step() {
        let n = nodes.count
        guard n > 0 else { return }

        var fx = [CGFloat](repeating: 0, count: n)
        var fy = [CGFloat](repeating: 0, count: n)
        let center = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)

        // Repulsion between every pair of nodes
        for i in 0..<n {
            for j in (i + 1)..<n {
                var dx = nodes[i].position.x - nodes[j].position.x
                var dy = nodes[i].position.y - nodes[j].position.y
                var distSq = dx * dx + dy * dy
                if distSq < 1 {
                    dx = CGFloat.random(in: -1...1)
                    dy = CGFloat.random(in: -1...1)
                    distSq = dx * dx + dy * dy + 0.01
                }
                let dist = sqrt(distSq)
                let force = repulsion / distSq
                let fdx = dx / dist * force
                let fdy = dy / dist * force
                fx[i] += fdx; fy[i] += fdy
                fx[j] -= fdx; fy[j] -= fdy
            }
        }

        // Springs along edges (containment relationships)
        for edge in edges {
            guard let ia = indexById[edge.a], let ib = indexById[edge.b] else { continue }
            let a = nodes[ia]; let b = nodes[ib]
            let dx = b.position.x - a.position.x
            let dy = b.position.y - a.position.y
            let dist = max(sqrt(dx * dx + dy * dy), 0.1)
            let displacement = dist - idealLength
            let force = displacement * springStrength
            let fdx = dx / dist * force
            let fdy = dy / dist * force
            fx[ia] += fdx; fy[ia] += fdy
            fx[ib] -= fdx; fy[ib] -= fdy
        }

        var totalMotion: CGFloat = 0
        for i in 0..<n {
            let node = nodes[i]
            fx[i] += (center.x - node.position.x) * centerPull
            fy[i] += (center.y - node.position.y) * centerPull

            guard !node.isDragging else { continue }
            node.velocity.dx = (node.velocity.dx + fx[i]) * damping
            node.velocity.dy = (node.velocity.dy + fy[i]) * damping
            node.position.x += node.velocity.dx
            node.position.y += node.velocity.dy
            totalMotion += abs(node.velocity.dx) + abs(node.velocity.dy)
        }

        tick &+= 1

        if totalMotion < CGFloat(n) * 0.05 {
            settledFrames += 1
            if settledFrames > 90 { stop() }
        } else {
            settledFrames = 0
        }
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Graph View

struct GraphView: View {
    @ObservedObject var store: NotebookStore
    @Binding var selectedNotebook: Notebook?
    @Binding var folderPath: [Folder]
    @Binding var showGraphView: Bool

    @StateObject private var engine = GraphEngine()

    @State private var scale: CGFloat = 1.0
    @State private var gestureScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var gestureOffset: CGSize = .zero
    @State private var viewportSize: CGSize = .zero
    @State private var hoveredNodeId: UUID?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if engine.nodes.isEmpty {
                    emptyState
                } else {
                    canvasContent
                        .frame(width: engine.worldSize.width, height: engine.worldSize.height)
                        .scaleEffect(scale * gestureScale)
                        .offset(x: offset.width + gestureOffset.width, y: offset.height + gestureOffset.height)
                        .gesture(SimultaneousGesture(magnificationGesture, panGesture))
                }

                controlsOverlay
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onAppear {
                viewportSize = proxy.size
                engine.build(folders: store.folders, notebooks: store.notebooks)
                centerCamera()
            }
            .onChange(of: proxy.size) { newSize in
                viewportSize = newSize
            }
            .onChange(of: store.folders) { _ in
                engine.build(folders: store.folders, notebooks: store.notebooks)
            }
            .onChange(of: store.notebooks) { _ in
                engine.build(folders: store.folders, notebooks: store.notebooks)
            }
        }
    }

    // MARK: Canvas Content

    private var canvasContent: some View {
        ZStack {
            Canvas { context, _ in
                for edge in engine.edges {
                    guard let a = engine.node(for: edge.a), let b = engine.node(for: edge.b) else { continue }
                    var path = Path()
                    path.move(to: a.position)
                    path.addLine(to: b.position)
                    context.stroke(path, with: .color(AppTheme.textSecondary.opacity(0.22)), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)

            ForEach(engine.nodes) { node in
                GraphNodeView(
                    node: node,
                    isHovered: hoveredNodeId == node.id,
                    isDimmed: hoveredNodeId != nil && !isConnected(node, to: hoveredNodeId!),
                    showLabel: scale * gestureScale > 0.65
                )
                .position(node.position)
                .onHover { hovering in
                    hoveredNodeId = hovering ? node.id : (hoveredNodeId == node.id ? nil : hoveredNodeId)
                }
                .highPriorityGesture(nodeDragGesture(node))
            }
        }
    }

    private func isConnected(_ node: GraphNode, to id: UUID) -> Bool {
        if node.id == id { return true }
        return engine.edges.contains { ($0.a == id && $0.b == node.id) || ($0.b == id && $0.a == node.id) }
    }

    // MARK: Gestures

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                gestureOffset = value.translation
            }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
                gestureOffset = .zero
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                gestureScale = value
            }
            .onEnded { value in
                scale = min(max(scale * value, 0.25), 3.0)
                gestureScale = 1.0
            }
    }

    private func nodeDragGesture(_ node: GraphNode) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !node.isDragging {
                    node.isDragging = true
                    node.dragOrigin = node.position
                }
                node.position = CGPoint(
                    x: node.dragOrigin.x + value.translation.width,
                    y: node.dragOrigin.y + value.translation.height
                )
                engine.wake()
            }
            .onEnded { value in
                node.isDragging = false
                let dist = hypot(value.translation.width, value.translation.height)
                if dist < 8 {
                    open(node)
                }
                engine.wake()
            }
    }

    // MARK: Navigation

    private func open(_ node: GraphNode) {
        switch node.kind {
        case .folder(let folder):
            navigateToFolder(folder)
        case .notebook(let notebook):
            if let parentId = notebook.folderId, let parentFolder = store.folders.first(where: { $0.id == parentId }) {
                navigateToFolder(parentFolder, animated: false)
            } else {
                folderPath = []
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedNotebook = notebook
            }
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showGraphView = false
        }
    }

    private func navigateToFolder(_ folder: Folder, animated: Bool = true) {
        var chain: [Folder] = []
        var current: Folder? = folder
        while let f = current {
            chain.insert(f, at: 0)
            current = f.parentFolderId.flatMap { pid in store.folders.first(where: { $0.id == pid }) }
        }
        if animated {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                folderPath = chain
            }
        } else {
            folderPath = chain
        }
    }

    // MARK: Camera

    private func centerCamera() {
        offset = CGSize(
            width: viewportSize.width / 2 - engine.worldSize.width / 2,
            height: viewportSize.height / 2 - engine.worldSize.height / 2
        )
    }

    // MARK: Overlays

    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showGraphView = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2.fill")
                        Text("Grade")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppTheme.surfaceElevated)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                    .shadow(color: AppTheme.shadowColor, radius: 6, y: 2)
                }
                .buttonStyle(.plain)

                Spacer()

                if !engine.nodes.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("\(engine.nodes.count) nós · \(engine.edges.count) conexões")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppTheme.surfaceElevated)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        scale = 1.0
                        centerCamera()
                    }
                    engine.wake()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(10)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.textMuted)
            Text("Nada para conectar ainda")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Crie pastas e cadernos para ver o grafo crescer.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textMuted)
        }
    }
}

// MARK: - Graph Node View

private struct GraphNodeView: View {
    let node: GraphNode
    let isHovered: Bool
    let isDimmed: Bool
    let showLabel: Bool

    private var color: Color {
        node.isFolder ? AppTheme.textSecondary : notebookSwiftColor(at: node.colorIndex)
    }

    private var radius: CGFloat {
        let base: CGFloat = node.isFolder ? 14 : 11
        return base + min(CGFloat(node.connectionCount), 8) * 1.6
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(isDimmed ? 0.18 : 0.85))
                    .frame(width: radius * 2, height: radius * 2)
                    .overlay(
                        Circle().stroke(
                            isHovered ? AppTheme.textPrimary : color.opacity(isDimmed ? 0.1 : 0.6),
                            lineWidth: isHovered ? 2.5 : 1
                        )
                    )
                    .shadow(color: isHovered ? color.opacity(0.6) : .clear, radius: 8)

                NoteIcon(icon: node.emoji, size: radius * 1.05)
                    .opacity(isDimmed ? 0.3 : 1)
            }

            if showLabel {
                Text(node.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isDimmed ? AppTheme.textMuted.opacity(0.4) : AppTheme.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isDimmed)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
