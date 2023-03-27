import SwiftUI
import AVFoundation
import CoreImage
import UIKit

// add to Info.plist

// Privacy - Photo Library Usage Description
// Privacy - Camera Usage Description

struct ContentView: View {
    var body: some View {
        VStack {
            CameraView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct CameraView: View {
    @StateObject var camera = CameraModel()
    @State var items : [Any] = []
    @State var sheet = false
    @State private var isLoading = false
    @State private var displayCapturedImage = false // to check if it is still rendered

    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                    .ignoresSafeArea(.all)
                    .opacity(camera.isTaken ? 0.0 : 1.0)
            
            if camera.isTaken && displayCapturedImage {
                Image(uiImage: UIImage(data: camera.picData) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .ignoresSafeArea()
            } else {
                if let image = camera.returnBackgroundImage() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                }
            }

            VStack {
                if camera.isTaken {
                    HStack {
                        Spacer()
                        Button(action: {
                            camera.reTake {
                                displayCapturedImage = false
                            }
                        },label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .foregroundColor(.black)
                                .padding()
                                .background(Color.white)
                                .clipShape(Circle())
                        }).padding(.trailing, 10)
                    }
                }
                Spacer()
                
                HStack {
                    // if taken showing save and again take button
                    if camera.isTaken{
                        // share image
                            Button(action: {
                                isLoading = true
                                items.removeAll()
                                items.append(camera.returnPhoto())
                                isLoading = false // Set isLoading to false after photo is loaded
                                sheet.toggle()
                            }, label: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.black)
                                    .padding()
                                    .fontWeight(.semibold)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .padding(.vertical,10)
                                    .padding(.horizontal,20)
                            })
                        .sheet(isPresented: $sheet, content: {
                            ShareSheet(items: items)
                        })
                        .overlay(
                            isLoading ? ProgressView() : nil
                        )
                        
                        Spacer()
                        Spacer()
                        
                        Button(action: {if !camera.isSaved{camera.savePic()}}, label: {
                            Text(camera.isSaved ? "Saved" : "Save")
                                .foregroundColor(.black)
                                .fontWeight(.semibold)
                                .padding(.vertical,10)
                                .padding(.horizontal,10)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .padding()
                                .font(.system(size: 25))
                            
                        })
                        Spacer()
                        Spacer()

                        HStack {
                        Menu {
                            Button(action: {
                                camera.sepiaFilter()
                            }, label: {
                                Text("Sepia")
                            })
                            Button(action: {
                                camera.colorFilter()
                            }, label: {
                                Text("Color Invert")
                            })
                            Button(action: {
                                camera.blurFilter()
                            }, label: {
                                Text("Blur")
                            })
                        } label: {
                            Label(
                                title: {  },
                                icon: { Image(systemName: "plus") }
                            ).padding(.vertical,20)
                                .padding(.horizontal,20)
                                .foregroundColor(.black)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .fontWeight(.semibold)
                                .padding()
                        }
                        
                    }
                }
                    else {
                        Spacer()
                        Button(action: {
                            camera.takePic {
                                displayCapturedImage = true
                            }
                        },label: {
                            ZStack {
                                Circle().fill(Color.white).frame(width:65,height: 65)
                                Circle().stroke(Color.white,lineWidth: 2).frame(width:75,height: 75)
                            }
                        })
                        Spacer()
                    }
                    
                }.frame(height: 75)
            }
        }
        .onAppear(perform: {
            camera.Check()
        })
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    // data you need to share
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    
    @Published var isTaken = false
    
    @Published var session = AVCaptureSession()
    
    @Published var alert = false
    // since were going to read pic data...
    @Published var output = AVCapturePhotoOutput()
    // preview...
    @Published var preview: AVCaptureVideoPreviewLayer!
    // Pic Data
    @Published var isSaved = false
    
    @Published var picData = Data(count: 0)
    
    @Published var filterName = "no"
    
    @Published var filteredImage: UIImage?
    
    @Published var backgroundImage: UIImage?
    
    func Check() {
        // ...
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (status) in
                if status {
                    self.setUp()
                }
            }
        case .denied:
            DispatchQueue.main.async {
                if let url = URL(string:UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
            break
        default:
            return
        }
    }
    
    func setUp() {
        DispatchQueue.global(qos: .background).async {
            do {
                self.session.beginConfiguration()
                
                var defaultCamera: AVCaptureDevice? {
                    if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                        print("Built-in dual camera found: \(device)")
                        return device
                    }
                    if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                        print("Built-in wide angle camera found: \(device)")
                        return device
                    }
                    return nil
                }
                
                let input = try AVCaptureDeviceInput(device: defaultCamera!)
                if self.session.canAddInput(input){
                    self.session.addInput(input)
                }
                if self.session.canAddOutput(self.output){
                    self.session.addOutput(self.output)
                }
                self.session.commitConfiguration()
                
                // Start running session in the background
                DispatchQueue.global(qos: .background).async {
                    self.session.startRunning()
                }
            }
            catch {
                print(error.localizedDescription)
            }
        }
    }
    
    
    func takePic(completion: @escaping () -> Void) {
        let settings = AVCapturePhotoSettings()
        self.output.capturePhoto(with: settings, delegate: self)
        
        DispatchQueue.main.async {
            withAnimation { self.isTaken.toggle() }
        }
        if let filteredImage = self.filteredImage {
            self.backgroundImage = filteredImage
        }
        completion()
    }
    
    func reTake(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            withAnimation { self.isTaken.toggle() }
            self.isSaved = false
            self.picData = Data()
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
            }
        }
        completion()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("Error converting photo to data")
            return
        }
        
        self.picData = imageData
        print("pic taken...")
        
        DispatchQueue.global(qos: .background).async {
            self.session.stopRunning()
        }
    }
    
    func savePic(){
        if let image = UIImage(data: self.picData)  {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            self.isSaved = true
            print("saved Sucessfully...")
        } else {
            print("Failed to save image: Invalid data")
            print(self.picData)
        }
        
    }
    
    func returnPhoto() -> UIImage {
        return UIImage(data: self.picData)!
    }
    
    func applyFilter(to image: UIImage) -> UIImage? {
        var filter = CIFilter(name: "no")
        guard let cgImage = image.cgImage else { return nil }
        let ciContext = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        // Apply filter
        switch(filterName) {
        case "sepia":
            filter = CIFilter(name: "CISepiaTone")
        case "color":
            filter = CIFilter(name: "CIColorInvert")
        case "blur":
            filter = CIFilter(name: "CIGaussianBlur")
        default :
            return image
        }
        
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        guard let outputCIImage = filter?.outputImage else { return nil }
        guard let outputCGImage = ciContext.createCGImage(outputCIImage, from: outputCIImage.extent) else { return nil }
        let outputImage = UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
        
        return outputImage
    }
    
    func sepiaFilter() {
        filterName = "sepia"
        if let image = applyFilter(to: UIImage(data: self.picData)!) {
            self.picData = image.pngData()! // picData is now filtered!!!
            self.isSaved = false
            print("sepia")
            if var image = UIImage(data: self.picData) {
                // Rotate image by 90 degrees clockwise
                image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .right)
                // Update picData with rotated image data
                if let rotatedImageData = image.jpegData(compressionQuality: 1.0) {
                    self.picData = rotatedImageData
                }
            }
        } else {
            print("Failed to save image: Invalid data")
            print(self.picData)
        }
    }
    
    func blurFilter() {
        filterName = "blur"
        if let image = applyFilter(to: UIImage(data: self.picData)!) {
            self.picData = image.pngData()! // picData is now filtered!!!
            self.isSaved = false
            print("blur")
            if var image = UIImage(data: self.picData) {
                // Rotate image by 90 degrees clockwise
                image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .right)
                // Update picData with rotated image data
                if let rotatedImageData = image.jpegData(compressionQuality: 1.0) {
                    self.picData = rotatedImageData
                }
            }
            
        } else {
            print("Failed to save image: Invalid data")
            print(self.picData)
        }
    }
    
    func colorFilter() {
        filterName = "color"
        if let image = applyFilter(to: UIImage(data: self.picData)!) {
            self.picData = image.pngData()! // picData is now filtered!!!
            self.isSaved = false
            print("color")
            if var image = UIImage(data: self.picData) {
                // Rotate image by 90 degrees clockwise
                image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .right)
                // Update picData with rotated image data
                if let rotatedImageData = image.jpegData(compressionQuality: 1.0) {
                    self.picData = rotatedImageData
                }
            }
        } else {
            print("Failed to save image: Invalid data")
            print(self.picData)
        }
    }
    
    func saveBackgroundImage() {
        guard let image = filteredImage else { return }
        backgroundImage = image
    }
    
    func returnBackgroundImage() -> UIImage? {
        return backgroundImage
    }
}
    
// setting view from preview
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel
    
    func makeUIView(context: Context) -> UIView{
        let view = UIView(frame: UIScreen.main.bounds)
        DispatchQueue.main.async {
            camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
            camera.preview.frame = view.frame
            
            // own properties...
            camera.preview.videoGravity = .resizeAspectFill
            view.layer.addSublayer(camera.preview)
        }
        DispatchQueue.global(qos: .background).async {
            camera.session.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        return
    }
}
