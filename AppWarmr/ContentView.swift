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
            photoCaptureDelegate.contentView = self
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
    // Reference to ContentView to trigger photo capture
    var contentView: ContentView?
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(),
           let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.capturedImage = image
              
                // Save to photo library and analyze with OpenAI
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.saveComplete), nil)
                self.analyzeImageWithOpenAI(image)
                
                print("Photo captured!")
            }
        }
    }
    
    private func analyzeImageWithOpenAI(_ image: UIImage) {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert image to data")
            return
        }
        let base64String = imageData.base64EncodedString()
        
        // Prepare the OpenAI API request
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openAIApiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64String)"
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Does this image contain a girl or woman? Please just answer yes or no."
                        ]
                    ]
                ]
            ],
            "response_format": [
                "type": "text"
            ],
            "temperature": 1,
            "max_tokens": 2048,
            "top_p": 1,
            "frequency_penalty": 0,
            "presence_penalty": 0
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Error creating request body: \(error)")
            return
        }
        
        // Send the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending image to OpenAI API: \(error)")
                return
            }
            
            if let data = data,
               let responseJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Process the response
                DispatchQueue.main.async {
                    self.handleOpenAIResponse(responseJson)
                }
            } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Received non-JSON response: \(responseString)")
            }
        }
        task.resume()
    }
  
  //do you think this post is the kind of post a target customer would enjoy for this business?
    
    private func handleOpenAIResponse(_ response: [String: Any]) {
        print("OpenAI Response: \(response)")
        
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            print("Could not parse OpenAI response")
            return
        }
        
        print("OpenAI Analysis: \(content)")
        
        // Check if the image contains a girl/woman and play sound if it does
        if content.lowercased().contains("yes") {
            print("Girl/woman detected in the image")
            SoundManager.playSound(fileName: "double_tap")
          DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(8)) {
            SoundManager.playSound(fileName: "scroll_down")
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                self?.captureNewImage()
            }
          }
        } else if content.lowercased().contains("no") {
            SoundManager.playSound(fileName: "scroll_down")
            // Auto-capture another image after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                self?.captureNewImage()
            }
        } else {
          SoundManager.playSound(fileName: "scroll_down")
        }
        // Here you can further process the analysis, display it to the user, etc.
    }
    
    // New function to trigger a new photo capture
    private func captureNewImage() {
        print("Auto-capturing new image...")
        contentView?.takePhoto()
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
