#if canImport(UIKit)
import SwiftUI
import Mantis
import PlatformKit

struct ImageCropView: UIViewControllerRepresentable {
    let imageData: Data
    var maxDimension: CGFloat = 600
    let onCropped: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CropWrapperViewController {
        guard let uiImage = UIImage(data: imageData) else {
            fatalError("Invalid image data")
        }

        let cropVC = Mantis.cropViewController(image: uiImage)
        cropVC.delegate = context.coordinator

        let wrapper = CropWrapperViewController()
        wrapper.addChild(cropVC)
        wrapper.view.addSubview(cropVC.view)
        cropVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cropVC.view.topAnchor.constraint(equalTo: wrapper.view.topAnchor),
            cropVC.view.bottomAnchor.constraint(equalTo: wrapper.view.bottomAnchor),
            cropVC.view.leadingAnchor.constraint(equalTo: wrapper.view.leadingAnchor),
            cropVC.view.trailingAnchor.constraint(equalTo: wrapper.view.trailingAnchor),
        ])
        cropVC.didMove(toParent: wrapper)

        return wrapper
    }

    func updateUIViewController(_ uiViewController: CropWrapperViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(maxDimension: maxDimension, onCropped: onCropped, onCancel: onCancel)
    }

    class Coordinator: NSObject, CropViewControllerDelegate {
        let maxDimension: CGFloat
        let onCropped: (Data) -> Void
        let onCancel: () -> Void

        init(maxDimension: CGFloat, onCropped: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.maxDimension = maxDimension
            self.onCropped = onCropped
            self.onCancel = onCancel
        }

        func cropViewControllerDidCrop(_ cropViewController: CropViewController, cropped: UIImage, transformation: Transformation, cropInfo: CropInfo) {
            if let data = cropped.jpegData(compressionQuality: 0.9),
               let jpeg = downsizedJPEGData(data, maxDimension: maxDimension) {
                onCropped(jpeg)
            }
        }

        func cropViewControllerDidFailToCrop(_ cropViewController: CropViewController, original: UIImage) {
            onCancel()
        }

        func cropViewControllerDidCancel(_ cropViewController: CropViewController, original: UIImage) {
            onCancel()
        }

        func cropViewControllerDidBeginResize(_ cropViewController: CropViewController) {}

        func cropViewControllerDidEndResize(_ cropViewController: CropViewController, original: UIImage, cropInfo: CropInfo) {}
    }
}

/// Wrapper that prevents Mantis from dismissing parent sheets
class CropWrapperViewController: UIViewController {
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        // Don't propagate dismiss - let SwiftUI handle it
        completion?()
    }
}

/// Present Mantis crop view directly via UIKit (avoids sheet-in-sheet issues)
enum CropPresenter {
    static func present(imageData: Data, maxDimension: CGFloat = 600, lockToScreenRatio: Bool = false, onCropped: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
        guard let uiImage = UIImage(data: imageData),
              let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        var config = Mantis.Config()
        if lockToScreenRatio {
            let viewSize = rootVC.view.bounds.size
            config.presetFixedRatioType = .canUseMultiplePresetFixedRatio(defaultRatio: viewSize.width / viewSize.height)
        }

        let cropVC = Mantis.cropViewController(image: uiImage, config: config)
        let coordinator = CropCoordinator(maxDimension: maxDimension, onCropped: { data in
            topVC.dismiss(animated: true) {
                onCropped(data)
            }
        }, onCancel: {
            topVC.dismiss(animated: true) {
                onCancel()
            }
        })
        cropVC.delegate = coordinator
        // Store coordinator to keep it alive
        objc_setAssociatedObject(cropVC, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        cropVC.modalPresentationStyle = .fullScreen
        topVC.present(cropVC, animated: true)
    }
}

private class CropCoordinator: NSObject, CropViewControllerDelegate {
    let maxDimension: CGFloat
    let onCropped: (Data) -> Void
    let onCancel: () -> Void

    init(maxDimension: CGFloat, onCropped: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
        self.maxDimension = maxDimension
        self.onCropped = onCropped
        self.onCancel = onCancel
    }

    func cropViewControllerDidCrop(_ cropViewController: CropViewController, cropped: UIImage, transformation: Transformation, cropInfo: CropInfo) {
        if let data = cropped.jpegData(compressionQuality: 0.9),
           let jpeg = downsizedJPEGData(data, maxDimension: maxDimension) {
            onCropped(jpeg)
        }
    }

    func cropViewControllerDidFailToCrop(_ cropViewController: CropViewController, original: UIImage) {
        onCancel()
    }

    func cropViewControllerDidCancel(_ cropViewController: CropViewController, original: UIImage) {
        onCancel()
    }

    func cropViewControllerDidBeginResize(_ cropViewController: CropViewController) {}
    func cropViewControllerDidEndResize(_ cropViewController: CropViewController, original: UIImage, cropInfo: CropInfo) {}
}
#endif
