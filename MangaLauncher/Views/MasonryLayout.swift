import SwiftUI
import ImageIO

struct MasonryLayout<Content: View>: View {
    let entries: [MangaEntry]
    let content: (MangaEntry) -> Content
    let columns = 2
    let spacing: CGFloat = 12

    init(entries: [MangaEntry], @ViewBuilder content: @escaping (MangaEntry) -> Content) {
        self.entries = entries
        self.content = content
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            let distributed = distributeEntries()
            ForEach(0..<columns, id: \.self) { column in
                VStack(spacing: spacing) {
                    ForEach(distributed[column], id: \.id) { entry in
                        content(entry)
                    }
                }
            }
        }
    }

    private func distributeEntries() -> [[MangaEntry]] {
        var columns: [[MangaEntry]] = Array(repeating: [], count: self.columns)
        var heights: [CGFloat] = Array(repeating: 0, count: self.columns)

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
