#if canImport(UIKit)
import SwiftUI
import SafariServices
import WebKit

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Overlay Browser Modifier

struct OverlayBrowserModifier: ViewModifier {
    @Binding var context: BrowserContext?
    @AppStorage(UserDefaultsKeys.browserMode) private var browserMode: String = "external"

    private var isActive: Bool { browserMode == "overlay" && context != nil }

    func body(content: Content) -> some View {
        content
            .overlay {
                if browserMode == "overlay", let ctx = context {
                    OverlayBrowserScreen(context: ctx) { context = nil }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .ignoresSafeArea(edges: .all)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: isActive)
            .sheet(item: browserMode != "overlay" ? $context : .constant(nil)) { ctx in
                SafariView(url: ctx.url)
                    .ignoresSafeArea()
            }
    }
}

extension View {
    func overlayBrowser(context: Binding<BrowserContext?>) -> some View {
        modifier(OverlayBrowserModifier(context: context))
    }
}

// MARK: - Web Layer (behind original content)

struct OverlayBrowserScreen: View {
    @Environment(\.openURL) private var openURL
    let context: BrowserContext
    let onDismiss: () -> Void
    @State private var currentURL: URL?
    @State private var showShareSheet = false
    @State private var isRevealed = false
    @State private var snapshot: UIImage?
    @State private var dragOffset: CGFloat = 0
    private var displayURL: URL { currentURL ?? context.url }
    private let screenHeight = UIScreen.main.bounds.height

    private var coverOffset: CGFloat {
        if !isRevealed { return 0 }
        return max(0, screenHeight + dragOffset * 2.5)
    }

    private var bottomBarOpacity: Double {
        if dragOffset >= 0 { return 1.0 }
        return max(0, 1.0 + Double(dragOffset) / (Double(screenHeight) * 0.25))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Color(.systemBackground)
                    .frame(height: UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.windows.first?.safeAreaInsets.top ?? 0)

                WebViewRepresentable(url: context.url, currentURL: $currentURL)

                VStack(spacing: 0) {
                    toolbarView

                    if context.entryName != nil {
                        entryCard
                    }
                }
                .background(Color(.systemBackground))
                .offset(y: dragOffset < 0 ? dragOffset : 0)
                .opacity(bottomBarOpacity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height < 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if abs(dragOffset) > screenHeight * 0.3 || value.predictedEndTranslation.height < -200 {
                                dismissAnimated()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
            .background(Color(.systemBackground))

            if let snapshot {
                let coverOpacity = isRevealed ? min(1.0, abs(dragOffset) / (screenHeight * 0.3)) : 1.0
                Image(uiImage: snapshot)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .offset(y: coverOffset)
                    .opacity(coverOpacity)
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(url: displayURL)
        }
        .onAppear {
            snapshot = captureScreenshot()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                isRevealed = true
            }
        }
    }

    private func captureScreenshot() -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }

    private func dismissAnimated() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            isRevealed = false
            dragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismiss()
        }
    }

    @ViewBuilder
    private var toolbarView: some View {
        HStack(spacing: 0) {
            Button { dismissAnimated() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }

            Spacer()

            Menu {
                Button {
                    showShareSheet = true
                } label: {
                    Label("共有する", systemImage: "square.and.arrow.up")
                }
                Button {
                    openURL(displayURL)
                } label: {
                    Label("ブラウザで開く", systemImage: "safari")
                }
                Button {
                    UIPasteboard.general.url = displayURL
                } label: {
                    Label("リンクをコピー", systemImage: "doc.on.doc")
                }
            } label: {
                HStack(spacing: 4) {
                    Text(displayURL.host ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
            }

            Spacer()

            Button {} label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var entryCard: some View {
        Divider()
        HStack(spacing: 12) {
            if let data = context.entryImageData, let image = data.toSwiftUIImage() {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                if let name = context.entryName {
                    Text(name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }
                if let publisher = context.entryPublisher, !publisher.isEmpty {
                    Text(publisher)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .padding(.bottom, UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0)
    }
}

// MARK: - WebView

private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var currentURL: URL?

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(currentURL: $currentURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var currentURL: URL?

        init(currentURL: Binding<URL?>) {
            _currentURL = currentURL
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            currentURL = webView.url
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
