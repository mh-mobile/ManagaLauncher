import SwiftData

extension ModelContext {
    func fetchLogged<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, caller: String = #function) -> [T] {
        do {
            return try fetch(descriptor)
        } catch {
            print("[ModelContext] fetch failed in \(caller): \(error)")
            return []
        }
    }

    func fetchCountLogged<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, caller: String = #function) -> Int {
        do {
            return try fetchCount(descriptor)
        } catch {
            print("[ModelContext] fetchCount failed in \(caller): \(error)")
            return 0
        }
    }
}
