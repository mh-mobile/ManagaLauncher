import SwiftUI

struct CatchUpSwipeOverlay: View {
    let offsetWidth: CGFloat

    var body: some View {
        if offsetWidth > 30 {
            RoundedRectangle(cornerRadius: 16)
                .fill(.green.opacity(0.2))
                .overlay {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("既読")
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                    }
                }
                .opacity(min(Double(offsetWidth) / 100, 1))
        } else if offsetWidth < -30 {
            RoundedRectangle(cornerRadius: 16)
                .fill(.orange.opacity(0.2))
                .overlay {
                    VStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)
                        Text("あとで")
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                    }
                }
                .opacity(min(Double(-offsetWidth) / 100, 1))
        }
    }
}
