//
//  CameraEngineRepresentable.swift
//  GlassQR
//

import SwiftUI
import AVFoundation

struct CameraEngineRepresentable: UIViewControllerRepresentable {
    @Binding var isTorchOn: Bool
    @Binding var isPaused: Bool
    @Binding var isSimulatedSession: Bool
    let onCodeDetected: (String) -> Void

    init(
        isTorchOn: Binding<Bool>,
        isPaused: Binding<Bool>,
        isSimulatedSession: Binding<Bool>,
        onCodeDetected: @escaping (String) -> Void
    ) {
        self._isTorchOn = isTorchOn
        self._isPaused = isPaused
        self._isSimulatedSession = isSimulatedSession
        self.onCodeDetected = onCodeDetected
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.setTorch(on: isTorchOn)
        uiViewController.setPaused(isPaused)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, CameraViewControllerDelegate {
        let parent: CameraEngineRepresentable

        init(parent: CameraEngineRepresentable) {
            self.parent = parent
        }

        func cameraViewController(_ controller: CameraViewController, didOutputCode code: String) {
            DispatchQueue.main.async {
                self.parent.onCodeDetected(code)
            }
        }

        func cameraViewControllerDidFallbackToSimulation(_ controller: CameraViewController) {
            DispatchQueue.main.async {
                self.parent.isSimulatedSession = true
            }
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: CameraViewController, didOutputCode code: String)
    func cameraViewControllerDidFallbackToSimulation(_ controller: CameraViewController)
}

final class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: CameraViewControllerDelegate?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isPausedInternal = false
    private let sessionQueue = DispatchQueue(label: "com.glassqr.camera.queue")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        #if targetEnvironment(simulator)
        delegate?.cameraViewControllerDidFallbackToSimulation(self)
        return
        #else
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.captureSession.canAddInput(videoInput) else {
                DispatchQueue.main.async {
                    self.delegate?.cameraViewControllerDidFallbackToSimulation(self)
                }
                return
            }

            self.captureSession.beginConfiguration()
            self.captureSession.addInput(videoInput)

            let metadataOutput = AVCaptureMetadataOutput()
            if self.captureSession.canAddOutput(metadataOutput) {
                self.captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            }
            self.captureSession.commitConfiguration()

            DispatchQueue.main.async {
                let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                layer.videoGravity = .resizeAspectFill
                layer.frame = self.view.bounds
                self.view.layer.addSublayer(layer)
                self.previewLayer = layer
            }

            self.captureSession.startRunning()
        }
        #endif
    }

    func setTorch(on: Bool) {
        #if !targetEnvironment(simulator)
        sessionQueue.async {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  device.hasTorch else { return }
            try? device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }
        #endif
    }

    func setPaused(_ paused: Bool) {
        isPausedInternal = paused
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if paused {
                if self.captureSession.isRunning {
                    self.captureSession.stopRunning()
                }
            } else {
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
            }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !isPausedInternal,
              let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObj.type == .qr,
              let stringVal = metadataObj.stringValue else { return }

        delegate?.cameraViewController(self, didOutputCode: stringVal)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            if self?.captureSession.isRunning == true {
                self?.captureSession.stopRunning()
            }
        }
    }
}
