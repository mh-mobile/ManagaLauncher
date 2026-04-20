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

// MARK: - Quick View Browser Screen

struct QuickViewBrowserScreen: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    let context: BrowserContext
    let onDismiss: () -> Void
    @State private var currentURL: URL?
    @State private var showShareSheet = false
    @State private var isRevealed = false
    @State private var snapshot: UIImage?
    @State private var dragOffset: CGFloat = 0
    @State private var reloadID = UUID()
    @State private var showControls = true
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

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Color(.systemBackground)
                    .frame(height: safeAreaTop)

                WebViewRepresentable(url: context.url, currentURL: $currentURL, reloadTrigger: $reloadID, onCenterTap: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls.toggle()
                    }
                })
            }

            if showControls {
                VStack(spacing: 0) {
                    toolbarView

                    if context.entryName != nil {
                        entryCard
                    }
                }
                .offset(y: dragOffset < 0 ? dragOffset : 0)
                .opacity(bottomBarOpacity)
                .contentShape(Rectangle())
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dragOffset = 0
                }
            }
        }
    }

    private func captureScreenshot() -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) else { return nil }
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
        HStack(spacing: 8) {
            Button { dismissAnimated() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.85))
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
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.85))
                .clipShape(Capsule())
            }

            Spacer()

            Button { reloadID = UUID() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.85))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var entryCard: some View {
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
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                if let publisher = context.entryPublisher, !publisher.isEmpty {
                    Text(publisher)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .padding(.bottom, UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0)
        .background(.black.opacity(0.85))
    }
}

// MARK: - WebView

private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var currentURL: URL?
    @Binding var reloadTrigger: UUID
    var onCenterTap: (() -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        context.coordinator.webView = webView

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        webView.addGestureRecognizer(tap)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onCenterTap = onCenterTap
        if context.coordinator.lastReloadTrigger != reloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            uiView.reload()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(currentURL: $currentURL, reloadTrigger: reloadTrigger, onCenterTap: onCenterTap)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, UIGestureRecognizerDelegate {
        @Binding var currentURL: URL?
        weak var webView: WKWebView?
        var lastReloadTrigger: UUID
        var onCenterTap: (() -> Void)?

        init(currentURL: Binding<URL?>, reloadTrigger: UUID, onCenterTap: (() -> Void)?) {
            _currentURL = currentURL
            self.lastReloadTrigger = reloadTrigger
            self.onCenterTap = onCenterTap
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            currentURL = webView.url
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let webView = gesture.view as? WKWebView else { return }
            let location = gesture.location(in: webView)

            let js = "document.elementFromPoint(\(location.x), \(location.y))?.closest('a, button, [onclick]') !== null"
            webView.evaluateJavaScript(js) { [weak self] result, _ in
                if let isInteractive = result as? Bool, !isInteractive {
                    DispatchQueue.main.async {
                        self?.onCenterTap?()
                    }
                }
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
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
