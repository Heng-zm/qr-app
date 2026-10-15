//
//  CameraEngineRepresentable.swift
//  GlassQR
//

import SwiftUI
import AVFoundation

struct CameraEngineRepresentable: UIViewControllerRepresentable {
    @Binding var isTorchOn: Bool
    @Binding var isPaused: Bool
    @Binding var zoomFactor: CGFloat
    @Binding var cameraPosition: AVCaptureDevice.Position
    @Binding var isSimulatedSession: Bool
    let onCodeDetected: (String) -> Void
    let onFocusPointTapped: ((CGPoint) -> Void)?

    init(
        isTorchOn: Binding<Bool>,
        isPaused: Binding<Bool>,
        zoomFactor: Binding<CGFloat>,
        cameraPosition: Binding<AVCaptureDevice.Position>,
        isSimulatedSession: Binding<Bool>,
        onCodeDetected: @escaping (String) -> Void,
        onFocusPointTapped: ((CGPoint) -> Void)? = nil
    ) {
        self._isTorchOn = isTorchOn
        self._isPaused = isPaused
        self._zoomFactor = zoomFactor
        self._cameraPosition = cameraPosition
        self._isSimulatedSession = isSimulatedSession
        self.onCodeDetected = onCodeDetected
        self.onFocusPointTapped = onFocusPointTapped
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.setTorch(on: isTorchOn)
        uiViewController.setPaused(isPaused)
        uiViewController.setZoom(zoomFactor)
        uiViewController.setCameraPosition(cameraPosition)
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

        func cameraViewController(_ controller: CameraViewController, didTapFocusAt point: CGPoint) {
            DispatchQueue.main.async {
                self.parent.onFocusPointTapped?(point)
            }
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: CameraViewController, didOutputCode code: String)
    func cameraViewControllerDidFallbackToSimulation(_ controller: CameraViewController)
    func cameraViewController(_ controller: CameraViewController, didTapFocusAt point: CGPoint)
}

final class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: CameraViewControllerDelegate?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isPausedInternal = false
    private var currentPosition: AVCaptureDevice.Position = .back
    private var currentZoomFactor: CGFloat = 1.0
    private let sessionQueue = DispatchQueue(label: "com.glassqr.camera.queue")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupTapGesture()
        setupCamera(position: currentPosition)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleFocusTap(_:)))
        view.addGestureRecognizer(tap)
    }

    @objc private func handleFocusTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: view)
        delegate?.cameraViewController(self, didTapFocusAt: location)

        #if !targetEnvironment(simulator)
        guard let preview = previewLayer else { return }
        let focusPoint = preview.captureDevicePointConverted(fromLayerPoint: location)
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.currentVideoDevice() else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                // Focus configuration handled silently
            }
        }
        #endif
    }

    private func currentVideoDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition)
    }

    private func setupCamera(position: AVCaptureDevice.Position) {
        currentPosition = position

        #if targetEnvironment(simulator)
        delegate?.cameraViewControllerDidFallbackToSimulation(self)
        return
        #else
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()
            self.captureSession.inputs.forEach { self.captureSession.removeInput($0) }
            self.captureSession.outputs.forEach { self.captureSession.removeOutput($0) }

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.captureSession.canAddInput(videoInput) else {
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async {
                    self.delegate?.cameraViewControllerDidFallbackToSimulation(self)
                }
                return
            }

            self.captureSession.addInput(videoInput)

            let metadataOutput = AVCaptureMetadataOutput()
            if self.captureSession.canAddOutput(metadataOutput) {
                self.captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            }
            self.captureSession.commitConfiguration()

            DispatchQueue.main.async {
                if self.previewLayer == nil {
                    let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                    layer.videoGravity = .resizeAspectFill
                    layer.frame = self.view.bounds
                    self.view.layer.addSublayer(layer)
                    self.previewLayer = layer
                }
            }

            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
        #endif
    }

    func setCameraPosition(_ position: AVCaptureDevice.Position) {
        guard position != currentPosition else { return }
        setupCamera(position: position)
    }

    func setZoom(_ zoom: CGFloat) {
        guard zoom != currentZoomFactor else { return }
        currentZoomFactor = zoom

        #if !targetEnvironment(simulator)
        sessionQueue.async { [weak self] in
            guard let device = self?.currentVideoDevice() else { return }
            do {
                try device.lockForConfiguration()
                let targetZoom = min(max(zoom, device.minAvailableVideoZoomFactor), min(device.maxAvailableVideoZoomFactor, 5.0))
                device.videoZoomFactor = targetZoom
                device.unlockForConfiguration()
            } catch {
                // Zoom configuration handled silently
            }
        }
        #endif
    }

    func setTorch(on: Bool) {
        #if !targetEnvironment(simulator)
        sessionQueue.async { [weak self] in
            guard let device = self?.currentVideoDevice(),
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
