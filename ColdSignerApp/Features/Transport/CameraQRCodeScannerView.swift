@preconcurrency import AVFoundation
import SwiftUI
import UIKit

enum CameraAccessState {
    case checking
    case authorized
    case denied
    case unavailable
}

struct CameraQRCodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onFailure: (String) -> Void

    func makeUIViewController(context: Context) -> CameraQRCodeScannerViewController {
        CameraQRCodeScannerViewController(onCode: onCode, onFailure: onFailure)
    }

    func updateUIViewController(
        _ uiViewController: CameraQRCodeScannerViewController,
        context: Context
    ) {}

    static func requestAccess() async -> CameraAccessState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            return granted ? .authorized : .denied
        @unknown default:
            return .unavailable
        }
    }
}

final class CameraQRCodeScannerViewController: UIViewController,
    AVCaptureMetadataOutputObjectsDelegate
{
    private let captureSession = AVCaptureSession()
    private let onCode: (String) -> Void
    private let onFailure: (String) -> Void
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false

    init(onCode: @escaping (String) -> Void, onFailure: @escaping (String) -> Void) {
        self.onCode = onCode
        self.onFailure = onFailure
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureIfNeeded()
        if isConfigured, !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              let device = AVCaptureDevice.default(for: .video)
        else {
            onFailure("相机不可用或尚未授权。")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let metadataOutput = AVCaptureMetadataOutput()
            captureSession.beginConfiguration()
            defer { captureSession.commitConfiguration() }

            guard captureSession.canAddInput(input),
                  captureSession.canAddOutput(metadataOutput)
            else {
                onFailure("无法初始化二维码扫描器。")
                return
            }

            captureSession.addInput(input)
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]

            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.insertSublayer(previewLayer, at: 0)
            self.previewLayer = previewLayer
            isConfigured = true
        } catch {
            onFailure("无法打开相机。签名器未保留任何画面。")
        }
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue
        else {
            return
        }
        Task { @MainActor [weak self] in
            self?.onCode(value)
        }
    }
}
