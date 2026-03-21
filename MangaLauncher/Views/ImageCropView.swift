#if canImport(UIKit)
import SwiftUI
import Mantis

struct ImageCropView: UIViewControllerRepresentable {
    let imageData: Data
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
        Coordinator(onCropped: onCropped, onCancel: onCancel)
    }

    class Coordinator: NSObject, CropViewControllerDelegate {
        let onCropped: (Data) -> Void
        let onCancel: () -> Void

        init(onCropped: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onCropped = onCropped
            self.onCancel = onCancel
        }

        func cropViewControllerDidCrop(_ cropViewController: CropViewController, cropped: UIImage, transformation: Transformation, cropInfo: CropInfo) {
            if let data = cropped.jpegData(compressionQuality: 0.9),
               let jpeg = downsizedJPEGData(data, maxDimension: 600) {
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
#endif
