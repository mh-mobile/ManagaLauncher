#if canImport(UIKit)
import SwiftUI

public struct WallpaperCropView: View {
    let imageData: Data
    var initialScale: CGFloat = 1.0
    var initialOffset: CGSize = .zero
    let onDone: (Data, CGFloat, CGSize) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showHint = true

    public init(imageData: Data, initialScale: CGFloat = 1.0, initialOffset: CGSize = .zero, onDone: @escaping (Data, CGFloat, CGSize) -> Void, onCancel: @escaping () -> Void) {
        self.imageData = imageData
        self.initialScale = initialScale
        self.initialOffset = initialOffset
        self.onDone = onDone
        self.onCancel = onCancel
    }

    public var body: some View {
        GeometryReader { geo in
            let screenSize = geo.size
            ZStack {
                Color.black.ignoresSafeArea()

                if let uiImage = UIImage(data: imageData) {
                    let imageSize = uiImage.size
                    let fillScale = max(screenSize.width / imageSize.width, screenSize.height / imageSize.height)

                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        offset = clampOffset(imageSize: imageSize, fillScale: fillScale, screenSize: screenSize)
                                    }
                                    lastOffset = offset
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, lastScale * value)
                                }
                                .onEnded { value in
                                    scale = max(1.0, lastScale * value)
                                    lastScale = scale
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        offset = clampOffset(imageSize: imageSize, fillScale: fillScale, screenSize: screenSize)
                                    }
                                    lastOffset = offset
                                }
                        )
                        .frame(width: screenSize.width, height: screenSize.height)
                        .clipped()
                }

                VStack {
                    HStack {
                        Button("キャンセル") {
                            onCancel()
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.15), in: RoundedRectangle(cornerRadius: 6))

                        Spacer()

                        Button("完了") {
                            if let uiImage = UIImage(data: imageData) {
                                let cropped = renderCrop(image: uiImage, screenSize: geo.size)
                                if let data = cropped.jpegData(compressionQuality: 0.9),
                                   let jpeg = downsizedJPEGData(data, maxDimension: 1200) {
                                    onDone(jpeg, scale, offset)
                                }
                            }
                        }
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color(red: 0.055, green: 0.055, blue: 0.055))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(red: 1.0, green: 0.553, blue: 0.553), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Spacer()

                    if showHint {
                        Text("ピンチで拡大・ドラッグで位置調整")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.15, green: 0.15, blue: 0.15), in: RoundedRectangle(cornerRadius: 4))
                            .transition(.opacity)
                    }

                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onAppear {
            scale = initialScale
            lastScale = initialScale
            offset = initialOffset
            lastOffset = initialOffset
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showHint = false
                }
            }
        }
    }

    private func clampOffset(imageSize: CGSize, fillScale: CGFloat, screenSize: CGSize) -> CGSize {
        let displayWidth = imageSize.width * fillScale * scale
        let displayHeight = imageSize.height * fillScale * scale

        let maxOffsetX = max(0, (displayWidth - screenSize.width) / 2)
        let maxOffsetY = max(0, (displayHeight - screenSize.height) / 2)

        return CGSize(
            width: min(maxOffsetX, max(-maxOffsetX, offset.width)),
            height: min(maxOffsetY, max(-maxOffsetY, offset.height))
        )
    }

    private func renderCrop(image: UIImage, screenSize: CGSize) -> UIImage {
        let fillScale = max(screenSize.width / image.size.width, screenSize.height / image.size.height)
        let displayWidth = image.size.width * fillScale * scale
        let displayHeight = image.size.height * fillScale * scale

        let imageOriginX = (screenSize.width - displayWidth) / 2 + offset.width
        let imageOriginY = (screenSize.height - displayHeight) / 2 + offset.height

        let pixelScale = image.size.width / (displayWidth)
        let cropRect = CGRect(
            x: -imageOriginX * pixelScale,
            y: -imageOriginY * pixelScale,
            width: screenSize.width * pixelScale,
            height: screenSize.height * pixelScale
        )

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

public enum WallpaperCropPresenter {
    public static func present(imageData: Data, initialScale: CGFloat = 1.0, initialOffset: CGSize = .zero, onDone: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let cropView = WallpaperCropView(imageData: imageData, initialScale: initialScale, initialOffset: initialOffset) { croppedData, finalScale, finalOffset in
            WallpaperManager.cropScale = finalScale
            WallpaperManager.cropOffsetX = finalOffset.width
            WallpaperManager.cropOffsetY = finalOffset.height
            topVC.dismiss(animated: true) {
                onDone(croppedData)
            }
        } onCancel: {
            topVC.dismiss(animated: true) {
                onCancel()
            }
        }

        let hostingVC = UIHostingController(rootView: cropView)
        hostingVC.modalPresentationStyle = .fullScreen
        topVC.present(hostingVC, animated: true)
    }
}
#endif
