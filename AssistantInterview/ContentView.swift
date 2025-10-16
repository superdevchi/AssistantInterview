import SwiftUI
import AVFoundation
import AppKit


//WORKING
final class ScreenCaptureManager: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    private var screenInput: AVCaptureScreenInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    
    @Published var isCapturing: Bool = false
    @Published var capturedImage: NSImage? = nil
    
    var binary: Data?
    var base64 = ""
    
    private var socket = WebSocketViewModel()
    
    override init() {
        super.init()
        // Initially configure for the main screen
        if let mainScreen = NSScreen.main {
            setupSession(for: mainScreen)
        }
    }
    
    /// Configures the capture session for a given screen.
    private func setupSession(for screen: NSScreen) {
        // Obtain the display number from the screen's device description.
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            print("Unable to get screen number")
            return
        }
        
        // Create an AVCaptureScreenInput for the given display ID.
        guard let input = AVCaptureScreenInput(displayID: screenNumber) else {
            print("Unable to create screen input")
            return
        }
        input.capturesCursor = true
        input.minFrameDuration = CMTime(value: 1, timescale: 30) // Capture at 30 FPS.
        self.screenInput = input
        
        // Add the input to the capture session.
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            print("Cannot add screen input")
        }
        
        // Configure and add the video output.
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            let queue = DispatchQueue(label: "ScreenCaptureQueue")
            videoOutput.setSampleBufferDelegate(self, queue: queue)
        } else {
            print("Cannot add video output")
        }
    }
    
    /// Reconfigures the capture session to share the selected screen.
    func reconfigure(for screen: NSScreen) {
        if captureSession.isRunning {
            stopCapture()
        }
        
        // Remove existing input if available.
        if let input = screenInput {
            captureSession.removeInput(input)
        }
        
        // Set up session with the new screen.
        setupSession(for: screen)
    }
    
    func startCapture() {
        if !captureSession.isRunning {
            captureSession.startRunning()
            DispatchQueue.main.async {
                self.isCapturing = true
            }
        }
    }
    
    func stopCapture() {
        if captureSession.isRunning {
            captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isCapturing = false
            }
        }
    }
}
extension ScreenCaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        // Process image on a high-QoS background queue
        DispatchQueue.global(qos: .userInitiated).async {
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: ciImage.extent.width, height: ciImage.extent.height))
                
                // Update UI on the main thread
                DispatchQueue.main.async {
                    self.capturedImage = nsImage
                }
                
                // Convert NSImage to JPEG data
                guard let tiffData = nsImage.tiffRepresentation,
                      let bitmapImage = NSBitmapImageRep(data: tiffData),
                      let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                    print("Failed to convert image to JPEG data")
                    return
                }
                
                // Encode JPEG data as base64 string
                self.binary = jpegData
                self.base64 = jpegData.base64EncodedString()
                
                // Now you could send the data over your WebSocket
                // e.g., socket.sendName(self.base64)
            }
        }
    }
}






















import Supabase

class SupabaseStorageManager {
    let supabaseClient: SupabaseClient

    init(supabaseURL: URL, supabaseKey: String) {
        self.supabaseClient = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }

    /// Uploads file data to a specified bucket and then returns the public URL via the completion handler.
    func uploadFile(fileData: Data, fileName: String, bucketName: String, completion: @escaping (String?) -> Void) {
        Task {
            do {
                // Optionally create file options (if needed)
                let options = FileOptions(cacheControl: "3600", upsert: true)
                // Use async/await to perform the upload.
                let postedFile = try await supabaseClient.storage
                    .from(bucketName)
                    .upload(fileName, data: fileData)
                
                print(" File uploaded successfully! \(postedFile)")
                
                // Retrieve the public URL (this method is synchronous)
//                let publicUrl = supabaseClient.storage
//                    .from(bucketName).getPublicUrl(path: fileName)
                
                let publicURL = try supabaseClient.storage
                  .from(bucketName)
                  .getPublicURL(path: fileName)

                print("url to send to grok" + publicURL.absoluteString)
                // Call the completion handler on success.
                completion(publicURL.absoluteString)
            } catch {
                print("Error uploading file to Supabase: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    

}

































import SwiftStomp
import Combine
import Compression

class WebSocketViewModel: ObservableObject {
    
    private let supbaseurl = URL(string: "https://zdzzzeiutwkfbtwmqfnv.supabase.co")
  
    var supbase: SupabaseStorageManager?
    @Published var messages: [ChatMessage] = [
//        ChatMessage(content: "Hello! How can I assist you today?", isCode: false, image: nil),
//        ChatMessage(content: """
//        ```swift
//        struct ContentView: View {
//            var body: some View {
//                Text("Hello, World!")
//            }
//        }
//        ```
//        """, isCode: true, image: nil),
//        ChatMessage(content: "Here's an image for you:", isCode: false, image: Image("exampleImage")),
    ]
    private var stompClient: SwiftStomp?
    private var subscriptions = Set<AnyCancellable>()  // Add this line
    
    // Create the connection URL
    private let url = URL(string: "ws://localhost:8094/gs-guide-websocket")!
    
   
   
    
    init() {
        // Initialize the stomp client with the URL
        self.stompClient = SwiftStomp(host: url)
        self.stompClient?.delegate = self // Set delegate to self
        self.stompClient?.autoReconnect = true // Enable auto reconnect
        
        
        self.supbase = SupabaseStorageManager(supabaseURL: self.supbaseurl!,supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpkenp6ZWl1dHdrZmJ0d21xZm52Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzM5MTU2NTgsImV4cCI6MjA0OTQ5MTY1OH0.3jKzr4712LZEEwPEoO-_Z1nm94_AvbxuMvKyiUFrqRk")
    }
    
    // Connect to the WebSocket server
    func connect() {
        // Attempt to connect and check the status
        print("Attempting to connect to WebSocket at \(url.absoluteString)")
        
        self.stompClient?.connect()
        
        switch self.stompClient?.connectionStatus {
        case .connecting:
            print("Connecting to the server...")
        case .socketConnected:
            print("Socket connected, STOMP sub-protocol not yet connected.")
        case .fullyConnected:
            print("Fully connected and ready for messaging!")
            
            
        case .socketDisconnected:
            print("Socket disconnected.")
        case .none:
            print("Connection status unknown.")
        }
        
        
        
    }
    
    // Disconnect from the WebSocket
    func disconnect() {
        print("Disconnecting from WebSocket")
        self.stompClient?.disconnect()
        
        
    }
    
    func generateRandomImageName(withExtension ext: String = "jpg") -> String {
        return "\(UUID().uuidString).\(ext)"
    }
    
    // Send a message to the WebSocket server
    func sendName(_ imageData: Data) async {
        guard let stompClient = self.stompClient else { return }
        
        // Check connection status
        if stompClient.connectionStatus != .fullyConnected {
            print("Not connected. Cannot send message.")
            return
        }
        
        
        
        
        do {
            
            
            
            await supbase?.uploadFile(fileData: imageData, fileName: generateRandomImageName(), bucketName: "images", completion: { result in
                
                print(result)
                
                let message = [
                    "from": "stream",
                    "text": result
                ]
                
                // Send message to the correct destination with headers and receiptId
                              
                // 1. Convert `Data` to `NSImage`
                if let nsImage = NSImage(data: imageData) {
                    // 2. Wrap `NSImage` in a SwiftUI Image
                    let swiftUIImage = Image(nsImage: nsImage)

                    // 3. Create a ChatMessage with the SwiftUI image
                    let imageInput = ChatMessage(
                        content: "Here’s the image I just uploaded to Chat. Generating response...",
//                        isCode: false,
                        isIncoming: false, image: swiftUIImage
                    )

                    // 4. Append to messages
                    
                    DispatchQueue.main.async {
                        self.messages.append(imageInput)
                    }
                    print("message image added")
                } else {
                    print("Failed to create NSImage from data.")
                }
                
                
                let receiptId = "msg-\(Int.random(in: 0..<1000))" // Generate a random receipt ID
                stompClient.send(body: message, to: "/app/chat", receiptId: receiptId, headers: ["content-type": "application/json"])
                
               
                
                print("Message sent to /app/chat: \(message)")
                
                
                
            }
                    
                                      
            )
        } catch {
            print("Error serializing JSON: \(error)")
        }
    }
    
    func sendchat(_ text: String) async {
        guard let stompClient = self.stompClient else { return }
        
        // Check connection status
        if stompClient.connectionStatus != .fullyConnected {
            print("Not connected. Cannot send message.")
            return
        }
        
        // Create the message dictionary containing the text
        let message = [
            "from": "stream",
            "text": text
        ]
        
        // Optionally, add the text message to your UI messages array
        let textMessage = ChatMessage(content: text, isIncoming: false, image: nil)
        DispatchQueue.main.async {
            self.messages.append(textMessage)
        }
        
        // Generate a random receipt ID
        let receiptId = "msg-\(Int.random(in: 0..<1000))"
        
        // Send the message via the STOMP client to the destination
        stompClient.send(body: message, to: "/app/chat/text", receiptId: receiptId, headers: ["content-type": "application/json"])
        print("Message sent to /app/chat/chat: \(message)")
    }
//

    
    
    
    func subscribeToMessages() {
        guard let stompClient = self.stompClient else { return }
        
        // 🛑 Unsubscribe from previous subscriptions (server-side cleanup)
        stompClient.unsubscribe(from: "/user/queue/messages")
        
        // 🛑 Remove previous Combine subscriptions (client-side cleanup)
        subscriptions.removeAll()
        
        print("Subscribing to /user/queue/messages...")
        stompClient.subscribe(to: "/user/queue/messages", mode: .clientIndividual)
        
        stompClient.messagesUpstream
            .receive(on: RunLoop.main)
            .sink { message in
                switch message {
                case let .text(text, _, destination, _):
                    print("✅ Received message at \(destination): \(text)")
                    self.handleMessage(text)
                case let .data(data, _, destination, _):
                    print("✅ Received binary message at \(destination): \(data.count) bytes")
                default:
                    print("⚠️ Received unexpected message type")
                }
            }
            .store(in: &subscriptions)
    }
    

    private func handleMessage(_ text: String) {
        DispatchQueue.main.async {
            self.messages.append(
                ChatMessage(content: text, isIncoming: true, image: nil)
            )
            print("Updated messages: \(self.messages)")
        }
    }
    
}

// MARK: - SwiftStomp Delegate
extension WebSocketViewModel: SwiftStompDelegate {
    func onConnect(swiftStomp: SwiftStomp, connectType: StompConnectType) {
        print("Connected with type: \(connectType)")
        
        self.subscribeToMessages()
        
        
    }
    
    func onDisconnect(swiftStomp: SwiftStomp, disconnectType: StompDisconnectType) {
        print("Disconnected with type: \(disconnectType)")
    }
    
    

    
    
        func onMessageReceived(swiftStomp: SwiftStomp, message: Any?, messageId: String, destination: String, headers: [String : String]) {
//              if destination == "/user/queue/messages", let text = message as? String {
//                  print("Received message at \(destination): \(text)")
////                  self.handleMessage(text)
//              }
          }
    
    func onReceipt(swiftStomp: SwiftStomp, receiptId: String) {
        print("Receipt received: \(receiptId)")
    }
    
    func onError(swiftStomp: SwiftStomp, briefDescription: String, fullDescription: String?, receiptId: String?, type: StompErrorType) {
        print("Error: \(briefDescription) - \(String(describing: fullDescription))")
    }
}






















//used for screen modal pop up on buttom
struct ScreenSelectionView: View {
    var screens: [NSScreen]
    var onSelect: (NSScreen) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Select Screen")
                .font(.headline)
                .padding(.top)
            
            List(0..<screens.count, id: \.self) { index in
                let screen = screens[index]
                Button(action: {
                    onSelect(screen)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text("Screen \(index + 1)")
                        Spacer()
                        Text("(\(Int(screen.frame.width)) x \(Int(screen.frame.height)))")
                    }
                }
                .buttonStyle(PlainButtonStyle()) // Ensures the button looks like a row.
            }
            .frame(minWidth: 300, minHeight: 200)
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding(.bottom)
        }
        .padding()
    }
}










func cleanUpText(_ text: String) -> String {
    var result = text
    
    // Remove sequences of asterisks (***, ****, etc.) by replacing them with a single asterisk.
    result = result.replacingOccurrences(of: "\\*{2,}", with: "*", options: .regularExpression)
    
    // Collapse multiple newlines into one.
    result = result.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
    
    // Remove markdown heading markers (e.g., "###", "##", "#") at the beginning of lines.
    result = result.replacingOccurrences(of: "^(\\s*#{1,6}\\s*)", with: "", options: .regularExpression)
    
    // Remove any stray "###" that might appear in the text.
    result = result.replacingOccurrences(of: "###", with: "", options: .literal)
    
    // Remove extraneous metadata lines (customize as needed).
    let lines = result.components(separatedBy: "\n")
    let filteredLines = lines.filter { line in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return !trimmed.hasPrefix("Updated messages:") &&
               !trimmed.hasPrefix("AssistantInterview.ChatMessage")
    }
    result = filteredLines.joined(separator: "\n")
    
    // Finally, trim leading and trailing whitespace/newlines.
    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    
    return result
}



// MARK: - Parsing Message Content

struct ParsedSegment: Identifiable {
    let id = UUID()
    let text: String
    let isCode: Bool
}

func parseMessageContent(_ content: String) -> [ParsedSegment] {
    let delimiter = "```"
    let components = content.components(separatedBy: delimiter)
    var segments = [ParsedSegment]()
    
    // Even indices: regular text, Odd indices: code
    for (index, part) in components.enumerated() {
        let cleaned = cleanUpText(part)
        let isCode = (index % 2 == 1)
        segments.append(ParsedSegment(text: cleaned, isCode: isCode))
    }
    return segments
}

// MARK: - ChatMessage Model

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isIncoming: Bool
    let image: Image?
    
    // Computed property to get cleaned and parsed segments
    var parsedSegments: [ParsedSegment] {
        parseMessageContent(content)
    }
}

// MARK: - ChatBubble View

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isIncoming {
                bubbleContent
                Spacer(minLength: 60)
            } else {
                Spacer(minLength: 60)
                bubbleContent
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
    
    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Display image if available
            if let image = message.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200)
            }
            // Iterate through the parsed segments and render accordingly
            ForEach(message.parsedSegments) { segment in
                if segment.isCode {
                    codeBlockView(text: segment.text)
                } else {
                    textBlockView(text: segment.text)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 10)
    }
    
    // View for code segments
    @ViewBuilder
    private func codeBlockView(text: String) -> some View {
        Group {
            if #available(iOS 15.0, macOS 12.0, *) {
                Text(text)
                    .textSelection(.enabled)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color(red: 25/255, green: 45/255, blue: 75/255)  // approx. #192D4B
)
                    .cornerRadius(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .contextMenu {
                        Button("Copy") { copyToPasteboard(text) }
                    }
            } else {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color(red: 25/255, green: 45/255, blue: 75/255)  // approx. #192D4B
)
                    .cornerRadius(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .contextMenu {
                        Button("Copy") { copyToPasteboard(text) }
                    }
            }
        }
    }
    
    // View for regular text segments
    @ViewBuilder
    private func textBlockView(text: String) -> some View {
        Group {
            if #available(iOS 15.0, macOS 12.0, *) {
                Text(text)
                    .textSelection(.enabled)
                    .foregroundColor(.white)
                    .padding(5)
                    .background(.clear)
                    .cornerRadius(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .contextMenu {
                        Button("Copy") { copyToPasteboard(text) }
                    }
            } else {
                Text(text)
                    .foregroundColor( .white)
                    .padding(5)
                    .background(.clear)
                    .cornerRadius(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .contextMenu {
                        Button("Copy") { copyToPasteboard(text) }
                    }
            }
        }
    }
    
    // Helper to copy text to clipboard
    func copyToPasteboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

// MARK: - ChatInterface View Example

struct ChatInterface: View {
    @ObservedObject var ws: WebSocketViewModel
    @State private var inputText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Scrollable chat messages area
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(ws.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .background(Color.clear)
                .onChange(of: ws.messages) { _ in
                    if let lastMessage = ws.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
                .padding(.horizontal)
            
            // Input area with text field and send button
            HStack {
                TextField("Type your message...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 8)

                
                Button(action: {
                    Task { await ws.sendchat(inputText) }
                }) {
                    Text("send")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }.buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding()
            .background(Color.clear)
        }
        .padding()
    }
}











//
//
//
//
//
//
//
//
//
//

import Foundation
import AVFoundation
import Speech
import Observation

public actor SpeechRecognizer: Observable {
    public enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case recognizerIsUnavailable
        
        public var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }
    
    @MainActor public var transcript: String = ""
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    
    public init() {
        recognizer = SFSpeechRecognizer()
        guard recognizer != nil else {
            transcribe(RecognizerError.nilRecognizer)
            return
        }
        
        Task {
            do {
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                // Mic permissions are granted by macOS system dialog — no manual check needed
            } catch {
                transcribe(error)
            }
        }
    }
    
    @MainActor public func startTranscribing() {
        Task {
            await transcribe()
        }
    }
    
    @MainActor public func resetTranscript() {
        Task {
            await reset()
        }
    }
    
    @MainActor public func stopTranscribing() {
        Task {
            await reset()
        }
    }
    
    private func transcribe() {
        guard let recognizer, recognizer.isAvailable else {
            self.transcribe(RecognizerError.recognizerIsUnavailable)
            return
        }
        
        do {
            let (audioEngine, request) = try Self.prepareEngine()
            self.audioEngine = audioEngine
            self.request = request
            self.task = recognizer.recognitionTask(with: request, resultHandler: { [weak self] result, error in
                self?.recognitionHandler(audioEngine: audioEngine, result: result, error: error)
            })
        } catch {
            self.reset()
            self.transcribe(error)
        }
    }
    
    private func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
    }
    
    private static func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        return (audioEngine, request)
    }
    
    nonisolated private func recognitionHandler(audioEngine: AVAudioEngine, result: SFSpeechRecognitionResult?, error: Error?) {
        let receivedFinalResult = result?.isFinal ?? false
        let receivedError = error != nil
        
        if receivedFinalResult || receivedError {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        if let result {
            transcribe(result.bestTranscription.formattedString)
        }
    }
    
    nonisolated private func transcribe(_ message: String) {
        Task { @MainActor in
            transcript = message
        }
    }
    
    nonisolated private func transcribe(_ error: Error) {
        let errorMessage = (error as? RecognizerError)?.message ?? error.localizedDescription
        Task { @MainActor [errorMessage] in
            transcript = "<< \(errorMessage) >>"
        }
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}



//
//
//
//
//
//
//
//
//
//
//
//
//
//
//









//working

struct ContentView: View {
    @StateObject private var screenCaptureManager = ScreenCaptureManager()
    @StateObject private var ws = WebSocketViewModel()
    
    @State private var selectedScreenIndex = 0
    @State private var transcriptEnabled = true
    @State private var yourTranscriptEnabled = true
    
    @State private var hiddenFromCapture = false
    
    
    @State private var transcribe = SpeechRecognizer()
    @State private var istranscribing: Bool = false
    
    

//    @StateObject private var recorder = AudioRecorder()

    private var screens: [NSScreen] {
        NSScreen.screens
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 79/255, green: 140/255, blue: 191/255),
                    Color(red: 120/255, green: 180/255, blue: 220/255)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    Text("Interview & Meeting Copilot")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()

                HStack {
                    Picker("Select Screen", selection: $selectedScreenIndex) {
                        ForEach(0..<screens.count, id: \.self) { index in
                            let screen = screens[index]
                            Text("Screen \(index + 1) (\(Int(screen.frame.width)) x \(Int(screen.frame.height)))")
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    .onChange(of: selectedScreenIndex) { newValue in
                        let chosenScreen = screens[newValue]
                        screenCaptureManager.reconfigure(for: chosenScreen)
                    }

                    Spacer()

                    Toggle(isOn: Binding(
                        get: { screenCaptureManager.isCapturing },
                        set: { newValue in
                            if newValue {
                                screenCaptureManager.startCapture()
                            } else {
                                screenCaptureManager.stopCapture()
                            }
                        }
                    )) {
                        Text("On").foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))

                    Button(action: { ws.connect() }) {
                        Text("Connect")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }.buttonStyle(PlainButtonStyle())

                    Button(action: { ws.disconnect() }) {
                        Text("Disconnect")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }.buttonStyle(PlainButtonStyle())

                    Button(action: {
                        Task { await ws.sendName(screenCaptureManager.binary!) }
                    }) {
                        Text("Broadcast")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }.buttonStyle(PlainButtonStyle())
                    
//                    Button(action: toggleCaptureVisibility) {
//                        Text(hiddenFromCapture ? "Show App to Capture" : "Hide App from Capture")
//                            .padding(.horizontal, 20)
//                            .padding(.vertical, 10)
//                            .background(RoundedRectangle(cornerRadius: 6).stroke())
//                    }
                

                }
                .padding()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.cyan)
                        Text("Accurate, real-time and tailored answers")
                            .foregroundColor(.white)
                    }
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.cyan)
                        Text("Tailored detailed feedbacks and correction")
                            .foregroundColor(.white)
                    }
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.cyan)
                        Text("Fully customizable to fit your needs")
                            .foregroundColor(.white)
                    }
                }
                .padding()

                HSplitView {
                    VStack(spacing: 10) {
                        ChatInterface(ws: ws)
                    }
                    .padding()
                    .frame(minWidth: 450)
                    .frame(height: 600)
                    .layoutPriority(1)

                    VStack(spacing: 10) {
                        ZStack {
                            if let capturedImage = screenCaptureManager.capturedImage {
                                Image(nsImage: capturedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(10)
                            } else {
                                Text("Begin Broadcasting")
                            }
                        }
                        .frame(height: 300)

                        
                        
                        Button(action:{
                            Task {
                                await toggletranscribe()
                            }
                        }
                                
                            
                        
                        ) {
                            Image( systemName: istranscribing ? "stop.circle.fill" :"microbe")
                                .font(.title2)
                                .foregroundColor(istranscribing ? .red : .blue)
                                .padding(2)
                                .clipShape(Circle())
                        }.padding(2)
                        

//                        Spacer()

//                        Toggle("Your Transcript", isOn: $yourTranscriptEnabled)
//                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(minWidth: 400)
                    .layoutPriority(0)
                }
                
                Spacer()
            }
        }
    }
    
    
    private func toggletranscribe() async{
        
        istranscribing.toggle()
        if istranscribing{
            
            transcribe.startTranscribing()
            
        }else{
            transcribe.stopTranscribing()
//            viewModel.userInput = transcribe.transcript
//            viewModel.sendMessage()
            print(transcribe.transcript)
            await ws.sendchat(transcribe.transcript)
        }
    }
    
    private func toggleCaptureVisibility() {
            hiddenFromCapture.toggle()

            // Grab the app’s key window (the one hosting this ContentView)
            guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return }

            // If hiddenFromCapture is true, mark it non‑capturable.
            // Otherwise restore normal (read-only) sharing.
            window.sharingType = hiddenFromCapture
                ? .none
                : .readOnly

            // (Optional) keep it above other windows so user doesn’t lose it
            window.level = hiddenFromCapture
                ? .floating
                : .normal
        }
}




// MARK: - PreviewProvider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
