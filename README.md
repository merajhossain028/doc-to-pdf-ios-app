# DOCX to PDF Converter

A SwiftUI application that allows users to upload DOC/DOCX files, preview their content, capture each page as an image, and convert those images into a single PDF. This app provides an intuitive and easy-to-use interface to handle DOCX files on iOS, leveraging SwiftUI, WebKit, PDFKit, and other modern technologies.

## Features

- **Upload DOC/DOCX Files**: Select DOC/DOCX files from your device using the built-in document picker.
- **Preview Document**: View the selected document using a WebView, with automatic page scrolling and image capturing.
- **Capture Pages as Images**: Each page of the DOC/DOCX file is captured as a high-quality image.
- **Unique Image Capture**: Ensures only unique pages are captured to avoid duplicates, using hashing techniques.
- **Convert to PDF**: Combine the captured images into a single PDF file for easy sharing and storage.
- **Download and Share PDF**: Preview the generated PDF within the app and download or share it using the system's share sheet.
- **Close Preview with Cross Button**: Close the document preview at any time using a toolbar with a cross button.
- **Alert on Completion**: Shows an alert when all pages are successfully captured.

## Technologies Used

- **SwiftUI**: For building the app's user interface.
- **WebKit (WKWebView)**: To render and interact with DOC/DOCX files.
- **PDFKit**: For creating and managing PDF documents.
- **QuickLook**: For previewing the generated PDF files.
- **CryptoKit**: To generate unique hashes for images to ensure only unique captures are processed.

## Getting Started

### Prerequisites

- Xcode 12 or later
- iOS 14.0 or later
- Basic knowledge of Swift and SwiftUI

### Installation

1. **Clone the Repository**:

    ```bash
    git clone https://github.com/your-username/docx-to-pdf-converter.git
    cd docx-to-pdf-converter
    ```

2. **Open the Project in Xcode**:

    Open `DOCXtoPDF.xcodeproj` in Xcode.

3. **Run the Project**:

    Select an iOS simulator or device and run the project using the play button in Xcode.

## Code Explanation

### 1. ContentView.swift

This is the main view of the app, where all interactions are managed.

- **State Variables**: Various `@State` properties are declared to manage the state of the application, such as the selected file URL, captured images, PDF URL, and the visibility of different views (like the document picker and preview).

    ```swift
    @State private var selectedFileURL: URL?
    @State private var capturedImages: [UIImage] = []
    @State private var convertedPDFURL: URL?
    @State private var isDocumentPickerPresented = false
    @State private var isPDFPreviewPresented = false
    @State private var isDOCPreviewPresented = false
    @State private var isShareSheetPresented = false
    @State private var totalPages: Int = 0
    @State private var showAlert: Bool = false
    ```

- **Upload Button**: A button to present the document picker for selecting DOC/DOCX files.

    ```swift
    Button(action: {
        isDocumentPickerPresented = true
    }) {
        Text("Upload DOC/DOCX File")
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    ```

- **Preview Button**: A button to open the document preview using `WKWebViewPreview`.

    ```swift
    Button(action: {
        isDOCPreviewPresented = true
    }) {
        Text("Captured Preview DOC/DOCX File")
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    ```

- **PDF Conversion**: After capturing images, this section allows converting those images into a single PDF document.

    ```swift
    Button(action: {
        convertImagesToPDF(images: capturedImages)
    }) {
        Text("Convert Images to Single PDF")
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    ```

- **PDF Preview and Download**: Buttons to preview the generated PDF and download/share it using the activity view.

    ```swift
    Button(action: {
        isPDFPreviewPresented = true
    }) {
        Text("Preview PDF")
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
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
    ```

### 2. WKWebViewPreview.swift

This structure is responsible for rendering the DOC/DOCX file in a `WKWebView` and capturing each page.

- **makeUIView**: Initializes a `WKWebView` and sets its navigation delegate.

    ```swift
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isPagingEnabled = true
        return webView
    }
    ```

- **capturePage**: Method to capture the current page of the WebView as an image. The method scrolls through each page, captures it, and checks if it's a unique image using hashing.

    ```swift
    func capturePage(_ webView: WKWebView) {
        guard currentPage < totalPages else {
            self.onImageCaptured(self.capturedImages)
            self.onAllPagesCaptured()
            return
        }

        let currentOffset = CGFloat(currentPage) * pageHeight
        webView.scrollView.setContentOffset(CGPoint(x: 0, y: currentOffset), animated: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            webView.takeSnapshot(with: nil) { [weak self] image, error in
                guard let self = self else { return }
                if let image = image, !self.isBlank(image) {
                    let imageHash = self.hashImage(image)
                    if !self.uniqueImageHashes.contains(imageHash) {
                        self.uniqueImageHashes.insert(imageHash)
                        self.capturedImages.append(image)
                        self.onImageCaptured(self.capturedImages)
                    }
                }
                
                self.currentPage += 1
                self.capturePage(webView)
            }
        }
    }
    ```

- **isBlank**: Checks if the captured image is mostly blank (white space).

    ```swift
    func isBlank(_ image: UIImage) -> Bool {
        // Logic to check if an image is blank by calculating white pixel ratio
    }
    ```

- **hashImage**: Generates a hash for each captured image to ensure uniqueness.

    ```swift
    func hashImage(_ image: UIImage) -> String {
        guard let imageData = image.pngData() else { return "" }
        let hash = SHA256.hash(data: imageData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    ```

### 3. QuickLookPreview.swift

- This structure uses `QuickLook` to preview the generated PDF file. It initializes a `QLPreviewController` and sets it up with the PDF URL.

    ```swift
    struct QuickLookPreview: UIViewControllerRepresentable {
        var url: URL
        
        func makeUIViewController(context: Context) -> QLPreviewController {
            let controller = QLPreviewController()
            controller.dataSource = context.coordinator
            return controller
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
    }
    ```

### 4. DocumentPicker.swift

- Manages the document picker, allowing the user to select DOC/DOCX files. The file URL is passed back to the `ContentView` for processing.

    ```swift
    struct DocumentPicker: UIViewControllerRepresentable {
        @Binding var selectedFileURL: URL?
        
        func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
            let docType = UTType(filenameExtension: "doc")!
            let docxType = UTType(filenameExtension: "docx")!
            
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [docType, docxType])
            documentPicker.allowsMultipleSelection = false
            documentPicker.delegate = context.coordinator
            return documentPicker
        }
    }
    ```

### 5. ActivityView.swift

- Provides an interface to share the generated PDF file using the system's share sheet.

    ```swift
    struct ActivityView: UIViewControllerRepresentable {
        let url: URL
        
        func makeUIViewController(context: Context) -> UIActivityViewController {
            let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            return activityViewController
        }
    }
    ```

## Future Improvements

- **Text Extraction**: Adding a feature to extract and display text from DOC/DOCX files.
- **Annotation Tools**: Allow users to annotate the captured images before converting them to PDF.
- **Error Handling**: Improve error handling and user feedback for file operations.

## Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request for bug fixes, enhancements, or new features.

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Make your changes.
4. Commit your changes (`git commit -m 'Add new feature'`).
5. Push to the branch (`git push origin feature-branch`).
6. Open a pull request.

## Contact

For any questions or feedback, please feel free to contact:

- **Md Meraj Hossain**: [meraj.hossain028@gmail.com](mailto:meraj.hossain028@gmail.com)
- **GitHub**: [merajhossain028](https://github.com/merajhossain028)

## Acknowledgments

- Apple Developer Documentation
- SwiftUI and WebKit community tutorials and examples
- Contributors and supporters of the project
