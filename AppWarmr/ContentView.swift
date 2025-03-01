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
    
    var body: some View {
        ZStack {
            if let previewLayer = previewLayer {
                CameraPreview(previewLayer: previewLayer)
                    .edgesIgnoringSafeArea(.all)
                
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
        
        // Get the front camera
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: frontCamera) else {
            print("Failed to access front camera")
            return
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
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, ObservableObject {
    @Published var capturedImage: UIImage?
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(),
           let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.capturedImage = image
              SoundManager.playSound(fileName: "double_tap")
                print("Photo captured!")
            }
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
