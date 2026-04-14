import SwiftUI
import WallpaperKit

@Observable
@MainActor
final class HomeState {
    // MARK: - Paging
    var paging = PagingState()

    // MARK: - Edit
    var edit = EditState()

    // MARK: - Wallpaper
    var wallpaper = WallpaperState.shared

    // MARK: - Sheets
    var sheets = SheetState()

    // MARK: - Layout
    var headerHeight: CGFloat = 50
    var selectedPublisher: String?
    var safariURL: URL?
    var commentingEntry: MangaEntry?
}

@Observable
final class PagingState {
    /// 初期値を今日の曜日に合わせることで、onAppear での pageIndex 変更による
    /// 不要なタブアニメーションを防止する。
    var pageIndex: Int
    var isAnimatingPageChange = false

    private let orderedDays = DayOfWeek.orderedDays

    init() {
        let days = DayOfWeek.orderedDays
        if let index = days.firstIndex(of: .today) {
            pageIndex = index + 1
        } else {
            pageIndex = 1
        }
    }

    func dayForPageIndex(_ index: Int) -> DayOfWeek {
        let count = orderedDays.count
        let clamped = ((index - 1) % count + count) % count
        return orderedDays[clamped]
    }

    func pageIndexForDay(_ day: DayOfWeek) -> Int {
        guard let index = orderedDays.firstIndex(of: day) else { return 1 }
        return index + 1
    }

    var currentDay: DayOfWeek {
        dayForPageIndex(pageIndex)
    }
}

@Observable
final class EditState {
    var isGridEditMode = false
    #if os(iOS) || os(visionOS)
    var listEditMode: EditMode = .inactive
    #endif
    var editingEntry: MangaEntry?
    var draggingEntryID: UUID?

    var isEditing: Bool {
        #if os(iOS) || os(visionOS)
        isGridEditMode || listEditMode == .active
        #else
        isGridEditMode
        #endif
    }

    func resetEditMode() {
        isGridEditMode = false
        #if os(iOS) || os(visionOS)
        listEditMode = .inactive
        #endif
    }
}

@Observable
final class WallpaperState {
    static let shared = WallpaperState()

    private init() {}

    var refresh = false
    var cachedWallpaperImage: Image?
    var previewActive = false
    var previewSnapshot = WallpaperPreviewSnapshot()

    var hasWallpaper: Bool { WallpaperManager.wallpaperType != .none }

    /// プレビュー中の壁紙も考慮した実効的な壁紙の有無
    var effectiveHasWallpaper: Bool {
        if previewActive { return previewSnapshot.wallpaperType != .none }
        return hasWallpaper
    }

    func loadImage() {
        if WallpaperManager.wallpaperType == .image,
           let data = WallpaperManager.loadImage(),
           let image = data.toSwiftUIImage() {
            cachedWallpaperImage = image
        } else {
            cachedWallpaperImage = nil
        }
    }
}

@Observable
final class SheetState {
    var showingAddSheet = false
    var showingCatchUp = false
    var showingWallpaperPicker = false
}
