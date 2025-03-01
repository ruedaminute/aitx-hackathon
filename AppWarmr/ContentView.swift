//
//  ContentView.swift
//  AppWarmr
//
//  Created by Michelle Rueda on 2/28/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var captureSession: AVCaptureSession?
    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    @State private var photoOutput = AVCapturePhotoOutput()
    @State private var capturedImage: UIImage?
    @StateObject private var photoCaptureDelegate = PhotoCaptureDelegate()
    @State private var zoomFactor: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            if let previewLayer = previewLayer {
                CameraPreview(previewLayer: previewLayer)
                    .edgesIgnoringSafeArea(.all)
                    .gesture(MagnificationGesture()
                        .onChanged { value in
                            zoom(factor: value)
                        }
                        .onEnded { value in
                            zoomFactor = min(max(value, 1.0), 5.0)
                        }
                    )
                    .onTapGesture { location in
                        focusCamera(at: location)
                    }
                
                VStack {
                    Spacer()
                    Button(action: {
                        takePhoto()
                    }) {
                        Image(systemName: "camera.circle.fill")
                            .resizable()
                            .frame(width: 70, height: 70)
                            .foregroundColor(.white)
                            .padding(.bottom, 30)
                    }
                }
            }
        }
        .onAppear {
            startCamera()
        }
    }
    
    func takePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: photoCaptureDelegate)
    }

    func startCamera() {
        // Set up the camera session
        let session = AVCaptureSession()
        
        // Get the rear camera instead of front camera
        guard let rearCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: rearCamera) else {
            print("Failed to access rear camera")
            return
        }
        
        // Configure camera for better focus
        do {
            try rearCamera.lockForConfiguration()
            if rearCamera.isFocusModeSupported(.continuousAutoFocus) {
                rearCamera.focusMode = .continuousAutoFocus
            }
            if rearCamera.isExposureModeSupported(.continuousAutoExposure) {
                rearCamera.exposureMode = .continuousAutoExposure
            }
            rearCamera.unlockForConfiguration()
        } catch {
            print("Error configuring camera: \(error.localizedDescription)")
        }
        
        // Add input to session
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        // Create preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        // Start running in background thread
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        
        // Store session and preview layer
        self.captureSession = session
        self.previewLayer = previewLayer
    }
    
    private func zoom(factor: CGFloat) {
        guard let device = (captureSession?.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            let zoomScale = min(max(factor, 1.0), device.activeFormat.videoMaxZoomFactor)
            device.videoZoomFactor = zoomScale
            
            device.unlockForConfiguration()
        } catch {
            print("Error setting zoom: \(error.localizedDescription)")
        }
    }
    
    private func focusCamera(at tapLocation: CGPoint) {
        guard let device = (captureSession?.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        
        let viewSize = UIScreen.main.bounds.size
        let focusPoint = CGPoint(
            x: tapLocation.y / viewSize.height,
            y: 1.0 - tapLocation.x / viewSize.width
        )
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error setting focus: \(error.localizedDescription)")
        }
    }
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, ObservableObject {
    @Published var capturedImage: UIImage?
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(),
           let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.capturedImage = image
                SoundManager.playSound(fileName: "double_tap")
                
                // Save to photo library
              UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.saveComplete), nil)
                
                print("Photo captured!")
            }
        }
    }
    
    @objc func saveComplete(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Error saving photo: \(error.localizedDescription)")
        } else {
            print("Photo saved successfully!")
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        previewLayer.frame = view.frame
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
    ContentView()
}
