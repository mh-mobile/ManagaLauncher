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
    private var displayURL: URL { currentURL ?? context.url }

    var body: some View {
        VStack(spacing: 0) {
            WebViewRepresentable(url: context.url, currentURL: $currentURL)

            toolbarView

            if context.entryName != nil {
                entryCard
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.height < -60 {
                                    onDismiss()
                                }
                            }
                    )
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(url: displayURL)
        }
    }

    @ViewBuilder
    private var toolbarView: some View {
        HStack(spacing: 0) {
            Button { onDismiss() } label: {
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
