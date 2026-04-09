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
    var wallpaper = WallpaperState()

    // MARK: - Sheets
    var sheets = SheetState()

    // MARK: - Layout
    var headerHeight: CGFloat = 50
    var selectedPublisher: String?
    var safariURL: URL?
}

@Observable
final class PagingState {
    var pageIndex: Int = 0
    var isAnimatingPageChange = false

    private let orderedDays = DayOfWeek.orderedCases

    func dayForPageIndex(_ index: Int) -> DayOfWeek {
        let clamped = ((index - 1) % 9 + 9) % 9
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
    var draggingIsOneShot = false

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
    var refresh = false
    var cachedWallpaperImage: Image?
    var previewActive = false
    var previewSnapshot = WallpaperPreviewSnapshot()

    var hasWallpaper: Bool { WallpaperManager.wallpaperType != .none }

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
    var showingSettings = false
    var showingCatchUp = false
    var showingWallpaperPicker = false
}
