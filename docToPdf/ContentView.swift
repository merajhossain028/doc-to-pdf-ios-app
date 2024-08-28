import SwiftUI
import UniformTypeIdentifiers
import WebKit
import PDFKit
import QuickLook
import CryptoKit // Import to use hashing functions

struct ContentView: View {
    @State private var selectedFileURL: URL?
    @State private var capturedImages: [UIImage] = []
    @State private var convertedPDFURL: URL?
    @State private var isDocumentPickerPresented = false
    @State private var isPDFPreviewPresented = false
    @State private var isDOCPreviewPresented = false
    @State private var isShareSheetPresented = false
    @State private var totalPages: Int = 0
    @State private var showAlert: Bool = false // State to control alert display

    var body: some View {
        VStack {
            // Step 1: Upload DOC/DOCX File
            Button(action: {
                isDocumentPickerPresented = true
            }) {
                Text("Upload DOC/DOCX File")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            // Step 2: Preview DOC/DOCX File
            if let url = selectedFileURL {
                Button(action: {
                    isDOCPreviewPresented = true
                }) {
                    Text("Captured Preview DOC/DOCX File")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top)
                .sheet(isPresented: $isDOCPreviewPresented) {
                    NavigationView { // Wrap in NavigationView to add toolbar
                        WKWebViewPreview(url: url, onImageCaptured: { images in
                            self.capturedImages = images
                        }, onPageCountCalculated: { totalPages in
                            self.totalPages = totalPages
                            print("Total number of pages: \(totalPages)")
                        }, onAllPagesCaptured: {
                            self.showAlert = true // Show alert when all pages are captured
                            isDOCPreviewPresented = false // Automatically close the preview
                        })
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: {
                                    isDOCPreviewPresented = false // Close the sheet
                                }) {
                                    Image(systemName: "xmark") // Cross icon
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                // Step 3: Convert Images to Single PDF
                if !capturedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(capturedImages, id: \.self) { image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .padding(.top)
                            }
                        }
                    }
                    
                    Button(action: {
                        convertImagesToPDF(images: capturedImages)
                    }) {
                        Text("Convert Images to Single PDF")
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top)
                }
                
                // Step 4: Preview and Download the PDF
                if let pdfURL = convertedPDFURL {
                    HStack {
                        Button(action: {
                            isPDFPreviewPresented = true
                        }) {
                            Text("Preview PDF")
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .sheet(isPresented: $isPDFPreviewPresented) {
                            QuickLookPreview(url: pdfURL)
                        }
                        
                        Button(action: {
                            isShareSheetPresented = true
                        }) {
                            Text("Download PDF")
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.leading)
                        .sheet(isPresented: $isShareSheetPresented) {
                            ActivityView(url: pdfURL)
                        }
                    }
                    .padding(.top)
                }
            }
        }
        .padding()
        .sheet(isPresented: $isDocumentPickerPresented) {
            DocumentPicker(selectedFileURL: $selectedFileURL)
        }
        .alert(isPresented: $showAlert) { // Show an alert when all pages are captured
            Alert(
                title: Text("Capture Complete"),
                message: Text("All pages have been captured successfully."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Function to Convert Images to Single PDF
    func convertImagesToPDF(images: [UIImage]) {
        let pdfDocument = PDFDocument()
        
        for (index, image) in images.enumerated() {
            if let pdfPage = PDFPage(image: image) {
                pdfDocument.insert(pdfPage, at: index)
            }
        }
        
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("ConvertedDocument.pdf")
        if pdfDocument.write(to: pdfURL) {
            self.convertedPDFURL = pdfURL
            print("Images converted to single PDF successfully.")
        } else {
            print("Failed to convert images to PDF.")
        }
    }
}

// WebView for Rendering DOCX Content and Capturing Each Page as Image
struct WKWebViewPreview: UIViewRepresentable {
    let url: URL
    var onImageCaptured: ([UIImage]) -> Void
    var onPageCountCalculated: (Int) -> Void  // Callback for total page count
    var onAllPagesCaptured: () -> Void // Callback for when all pages are captured

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isPagingEnabled = true
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadFileURL(url, allowingReadAccessTo: url)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, onImageCaptured: onImageCaptured, onPageCountCalculated: onPageCountCalculated, onAllPagesCaptured: onAllPagesCaptured)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WKWebViewPreview
        var onImageCaptured: ([UIImage]) -> Void
        var onPageCountCalculated: (Int) -> Void
        var onAllPagesCaptured: () -> Void // Callback for when all pages are captured
        var capturedImages: [UIImage] = []
        var uniqueImageHashes: Set<String> = [] // Set to store unique image hashes
        var totalPages: Int = 0
        var currentPage: Int = 0
        var pageHeight: CGFloat = 0

        init(_ parent: WKWebViewPreview, onImageCaptured: @escaping ([UIImage]) -> Void, onPageCountCalculated: @escaping (Int) -> Void, onAllPagesCaptured: @escaping () -> Void) {
            self.parent = parent
            self.onImageCaptured = onImageCaptured
            self.onPageCountCalculated = onPageCountCalculated
            self.onAllPagesCaptured = onAllPagesCaptured
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Calculate total number of pages
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, error in
                guard let self = self, let height = result as? CGFloat, error == nil else {
                    print("Failed to get content height.")
                    return
                }
                self.pageHeight = webView.bounds.height
                self.totalPages = Int(ceil(height / self.pageHeight))
                self.onPageCountCalculated(self.totalPages)  // Inform total page count
                self.currentPage = 0 // Start capturing from the very first page
                // Delay to allow WebView to properly load and render
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.capturePage(webView)
                }
            }
        }

        func capturePage(_ webView: WKWebView) {
            // Stop capturing if we have reached the total number of pages
            guard currentPage < totalPages else {
                self.onImageCaptured(self.capturedImages) // Return all captured images
                self.onAllPagesCaptured() // Notify that all pages have been captured
                return
            }

            let currentOffset = CGFloat(currentPage) * pageHeight // Correct offset calculation
            webView.scrollView.setContentOffset(CGPoint(x: 0, y: currentOffset), animated: false)
            
            // Allow the WebView to render content and wait for any rendering delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {  // Adding a slight delay to allow the WebView to adjust
                webView.takeSnapshot(with: nil) { [weak self] image, error in
                    guard let self = self else { return }
                    if let image = image, !self.isBlank(image) {
                        let imageHash = self.hashImage(image)
                        if !self.uniqueImageHashes.contains(imageHash) {
                            self.uniqueImageHashes.insert(imageHash)
                            self.capturedImages.append(image)
                            self.onImageCaptured(self.capturedImages) // Capture unique image
                        }
                    }
                    
                    self.currentPage += 1
                    self.capturePage(webView)
                }
            }
        }
        
        // Function to check if an image is blank
        func isBlank(_ image: UIImage) -> Bool {
            guard let cgImage = image.cgImage else { return true }
            let width = cgImage.width
            let height = cgImage.height
            let colorSpace = CGColorSpaceCreateDeviceGray()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
            
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            guard let pixelData = context?.data else { return true }
            
            let data = pixelData.bindMemory(to: UInt8.self, capacity: width * height)
            let threshold = 0.99 // 99% white pixels considered as blank
            let whitePixelCount = (0..<width * height).reduce(0) { $0 + (data[$1] == 255 ? 1 : 0) }
            
            return Double(whitePixelCount) / Double(width * height) > threshold
        }
        
        // Function to hash an image
        func hashImage(_ image: UIImage) -> String {
            guard let imageData = image.pngData() else { return "" }
            let hash = SHA256.hash(data: imageData)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        }
    }
}

// QuickLook Preview for DOC and PDF
struct QuickLookPreview: UIViewControllerRepresentable {
    var url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookPreview
        
        init(_ parent: QuickLookPreview) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}

// Document Picker for Selecting DOC/DOCX Files
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFileURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let docType = UTType(filenameExtension: "doc")!
        let docxType = UTType(filenameExtension: "docx")!
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [docType, docxType])
        documentPicker.allowsMultipleSelection = false
        documentPicker.delegate = context.coordinator
        return documentPicker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedFileURL = urls.first else {
                print("No file selected.")
                return
            }

            // Start accessing a security-scoped resource.
            if selectedFileURL.startAccessingSecurityScopedResource() {
                defer { selectedFileURL.stopAccessingSecurityScopedResource() }

                parent.selectedFileURL = selectedFileURL
                print("Selected file URL: \(selectedFileURL.path)")
            } else {
                print("Failed to access security-scoped resource.")
            }
        }
    }
}

// ActivityView for Sharing the PDF
struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        return activityViewController
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
