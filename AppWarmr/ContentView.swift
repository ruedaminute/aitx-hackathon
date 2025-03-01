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
    
    // Add states for the information modal
    @State private var showInfoModal: Bool = false
    @State private var businessInfo: String = ""
    @State private var idealCustomerInfo: String = ""
    
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
                    HStack {
                        Spacer()
                        // Add the question mark button
                        Button(action: {
                            showInfoModal = true
                        }) {
                            Image(systemName: "questionmark.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                                .padding(.top, 50)
                                .padding(.trailing, 20)
                        }
                    }
                    
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
            
            // Show the information collection modal when needed
            if showInfoModal {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                
                BusinessInfoModal(
                    businessInfo: $businessInfo,
                    idealCustomerInfo: $idealCustomerInfo,
                    isPresented: $showInfoModal,
                    onComplete: {
                        photoCaptureDelegate.businessInfo = businessInfo
                        photoCaptureDelegate.idealCustomerInfo = idealCustomerInfo
                        
                        // Get Groq response from UserDefaults
                        if let storedGroqResponse = UserDefaults.standard.string(forKey: "groqResponse") {
                            photoCaptureDelegate.groqResponse = storedGroqResponse
                        }
                        
                        showInfoModal = false
                    }
                )
                .frame(width: UIScreen.main.bounds.width * 0.9)
                .background(Color.white)
                .cornerRadius(15)
                .shadow(radius: 10)
                .padding()
            }
        }
        .onAppear {
            startCamera()
            photoCaptureDelegate.contentView = self
            
            // Check if business and customer info already exists in UserDefaults
            if let storedBusinessInfo = UserDefaults.standard.string(forKey: "businessInfo"),
               let storedCustomerInfo = UserDefaults.standard.string(forKey: "idealCustomerInfo"),
               !storedBusinessInfo.isEmpty, !storedCustomerInfo.isEmpty {
                // Use stored values
                businessInfo = storedBusinessInfo
                idealCustomerInfo = storedCustomerInfo
                photoCaptureDelegate.businessInfo = storedBusinessInfo
                photoCaptureDelegate.idealCustomerInfo = storedCustomerInfo
                
                // Also load the stored Groq response
                if let storedGroqResponse = UserDefaults.standard.string(forKey: "groqResponse") {
                    photoCaptureDelegate.groqResponse = storedGroqResponse
                }
                
                showInfoModal = false
            } else {
                // Show modal to collect information
                showInfoModal = true
            }
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

// Create a new struct for the business info modal
struct BusinessInfoModal: View {
    @Binding var businessInfo: String
    @Binding var idealCustomerInfo: String
    @Binding var isPresented: Bool
    @State private var isLoading: Bool = false
    @State private var groqResponse: String = ""
    @State private var showGroqResponse: Bool = false
    
    var onComplete: () -> Void
    
    // Groq API key - you should store this securely in a production app
    private let groqApiKey = "YOUR_GROQ_API_KEY"
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Text("Welcome to AcctWarmer")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.top)
                
                if showGroqResponse {
                    // Display Groq response
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Groq Analysis:")
                                .font(.headline)
                                .padding(.bottom, 5)

                            Text(groqResponse)
                                .font(.body)
                                .foregroundColor(.black)
                        }
                        .padding()
                    }
                    .frame(height: 300)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    Button(action: {
                        // Save to UserDefaults and continue
                        UserDefaults.standard.set(businessInfo, forKey: "businessInfo")
                        UserDefaults.standard.set(idealCustomerInfo, forKey: "idealCustomerInfo")
                        UserDefaults.standard.set(groqResponse, forKey: "groqResponse")
                        onComplete()
                    }) {
                        Text("Continue to Camera")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.bottom)
                } else {
                    // Display input form with fixed styling
                    VStack(alignment: .leading) {
                        Text("What is your business?")
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $businessInfo)
                                .padding(5)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                )
                            
                            if businessInfo.isEmpty {
                                Text("Describe your business")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading) {
                        Text("What is your ideal customer?")
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $idealCustomerInfo)
                                .padding(5)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                )
                            
                            if idealCustomerInfo.isEmpty {
                                Text("Describe your ideal customer")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        isLoading = true
                        sendToGroq()
                    }) {
                        Text("Continue")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(
                                businessInfo.isEmpty || idealCustomerInfo.isEmpty 
                                ? Color.gray 
                                : Color.blue
                            )
                            .cornerRadius(10)
                    }
                    .disabled(businessInfo.isEmpty || idealCustomerInfo.isEmpty || isLoading)
                    .padding(.bottom)
                }
            }
            .background(Color.white)
            .cornerRadius(15)
            
            if isLoading {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
    
    private func sendToGroq() {
        Task {
            do {
                let response = try await LLMService.sendToGroq(businessInfo: businessInfo, idealCustomerInfo: idealCustomerInfo)
                
                // Update the UI on the main thread
                await MainActor.run {
                    isLoading = false
                    groqResponse = response
                    showGroqResponse = true
                }
            } catch {
                // Handle errors
                await MainActor.run {
                    isLoading = false
                    groqResponse = "Error: \(error.localizedDescription)"
                    showGroqResponse = true
                }
            }
        }
    }
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, ObservableObject {
    @Published var capturedImage: UIImage?

    // Reference to ContentView to trigger photo capture
    var contentView: ContentView?
    
    // Add properties for business and customer info
    var businessInfo: String = ""
    var idealCustomerInfo: String = ""
    var groqResponse: String? = nil
    
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
        request.setValue("Bearer \(ServiceKeys.openAIApiKey)", forHTTPHeaderField: "Authorization")
        
        // Update the prompt to ask for justification and return JSON with an example
        let promptText: String
        if let response = groqResponse {
            promptText = """
            Does this image contain content that fits the following description? \(response)
            
            Please respond with JSON in the following format:
            {
                "answer": "yes" or "no",
                "justification": "Your reasoning explaining why the image does or doesn't match the description"
            }
            """
        } else {
            promptText = """
            Does this image contain a girl or woman?
            
            Please respond with JSON in the following format:
            {
                "answer": "yes" or "no",
                "justification": "Your reasoning explaining why you identified a girl/woman or not in the image"
            }
            """
        }
        
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
                            "text": promptText
                        ]
                    ]
                ]
            ],
            "response_format": [
                "type": "json_object" // Change to JSON format
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
    
    private func handleOpenAIResponse(_ response: [String: Any]) {
        print("OpenAI Response: \(response)")
        
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            print("Could not parse OpenAI response")
            return
        }
        
        // Parse the JSON content from the response
        do {
            if let contentData = content.data(using: .utf8),
               let jsonResponse = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
                
                // Extract answer and justification
                let containsContent = (jsonResponse["answer"] as? String)?.lowercased() ?? ""
                let justification = jsonResponse["justification"] as? String ?? "No justification provided"
                
                print("OpenAI Analysis: \(containsContent)")
                print("Justification: \(justification)")
                
                // Check if the image contains relevant content and play sound if it does
                if containsContent.contains("yes") {
                    print("Relevant content detected in the image")
                    SoundManager.playSound(fileName: "double_tap")
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10)) {
                        SoundManager.playSound(fileName: "scroll_down")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
                            self?.captureNewImage()
                        }
                    }
                } else if containsContent.contains("no") {
                    SoundManager.playSound(fileName: "scroll_down")
                    // Auto-capture another image after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
                        self?.captureNewImage()
                    }
                } else {
                    SoundManager.playSound(fileName: "scroll_down")
                    // Handle unexpected response
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
                        self?.captureNewImage()
                    }
                }
            } else {
                // Fallback for non-JSON responses (should not happen with response_format set to json_object)
                let containsYes = content.lowercased().contains("yes")
                
                if containsYes {
                    print("Relevant content detected in the image (fallback parsing)")
                    SoundManager.playSound(fileName: "double_tap")
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10)) {
                        SoundManager.playSound(fileName: "scroll_down")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                            self?.captureNewImage()
                        }
                    }
                } else {
                    SoundManager.playSound(fileName: "scroll_down")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                        self?.captureNewImage()
                    }
                }
            }
        } catch {
            print("Error parsing JSON content: \(error)")
            
            // Fallback to simple text parsing
            let containsYes = content.lowercased().contains("yes")
            
            if containsYes {
                SoundManager.playSound(fileName: "double_tap")
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10)) {
                    SoundManager.playSound(fileName: "scroll_down")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                        self?.captureNewImage()
                    }
                }
            } else {
                SoundManager.playSound(fileName: "scroll_down")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    self?.captureNewImage()
                }
            }
        }
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
