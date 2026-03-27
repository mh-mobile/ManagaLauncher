import SwiftUI
import ImageIO

struct MasonryLayout<Content: View>: View {
    let entries: [MangaEntry]
    let availableWidth: CGFloat
    let content: (MangaEntry) -> Content
    let spacing: CGFloat = 12
    private let idealColumnWidth: CGFloat = 170
    private let minColumns = 2
    private let maxColumns = 4

    init(entries: [MangaEntry], availableWidth: CGFloat, @ViewBuilder content: @escaping (MangaEntry) -> Content) {
        self.entries = entries
        self.availableWidth = availableWidth
        self.content = content
    }

    var body: some View {
        let columnCount = columnCount(for: availableWidth)
        let distributed = distributeEntries(into: columnCount)
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<columnCount, id: \.self) { column in
                VStack(spacing: spacing) {
                    ForEach(distributed[column], id: \.id) { entry in
                        content(entry)
                    }
                }
            }
        }
    }

    private func columnCount(for width: CGFloat) -> Int {
        guard width > 0 else { return minColumns }
        let countByWidth = Int(width / idealColumnWidth)
        let clamped = min(max(countByWidth, minColumns), maxColumns)
        return min(clamped, max(entries.count, 1))
    }

    private func distributeEntries(into columnCount: Int) -> [[MangaEntry]] {
        var columns: [[MangaEntry]] = Array(repeating: [], count: columnCount)
        var heights: [CGFloat] = Array(repeating: 0, count: columnCount)

        for entry in entries {
            let ratio = imageAspectRatio(for: entry)
            let shortestColumn = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[shortestColumn].append(entry)
            // Estimate height: width=1, height=1/ratio, plus text area (~40pt)
            heights[shortestColumn] += (1.0 / ratio) + 40
        }
        return columns
    }

    private func imageAspectRatio(for entry: MangaEntry) -> CGFloat {
        guard let data = entry.imageData,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              height > 0 else {
            return 3.0 / 4.0 // default for no-image cells
        }
        return width / height
    }
}
