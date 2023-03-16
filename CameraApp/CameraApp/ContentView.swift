import SwiftUI
import AVFoundation

// to Info.plist

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
    var body: some View {
        ZStack {
            //camera preview
            CameraPreview(camera: camera)
            .ignoresSafeArea(.all, edges: .all)
            
            VStack {
                if camera.isTaken{
                    HStack {
                        Spacer()
                        
                        Button(action: camera.reTake, label: {
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
                        Button(action: {if !camera.isSaved{camera.savePic()}}, label: {
                            Text(camera.isSaved ? "Saved" : "Save")
                                .foregroundColor(.black)
                                .fontWeight(.semibold)
                                .padding(.vertical,10)
                                .padding(.horizontal,20)
                                .background(Color.white)
                                .clipShape(Capsule())
                        })
                        .padding(.leading)
                        
                        Spacer()
                    }
                    else {
                        Button(action: camera.takePic, label: {
                            ZStack {
                                Circle().fill(Color.white).frame(width:65,height: 65)
                                Circle().stroke(Color.white,lineWidth: 2).frame(width:75,height: 75)
                            }
                        })
                    }
                }.frame(height: 75)
                
            }
        }
        .onAppear(perform: {
            camera.Check()
        })
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
    
    func Check(){
        
        //first checking camera has got permission...
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
            //Setting Up Session
        case .notDetermined:
            //returning for permission...
            AVCaptureDevice.requestAccess(for: .video) {
                (status) in
                if status {
                    self.setUp()
                }
            }
        case .denied:
            self.alert.toggle()
            return
        default:
            return
        }
    }
    func setUp(){
        
        // setting up camera...
        do{
            
            // setting configs...
            self.session.beginConfiguration()
            
            // change for own...
            var defaultCamera: AVCaptureDevice? {
                if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back){
                    print("Built-in dual camera found: \(device)")
                    return device
                }
                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                    print("Built-in wide angle camera found: \(device)")
                    return device
                }
                
                return nil
            }
            
            // need phisycal device! not simulator
            let input = try AVCaptureDeviceInput(device: defaultCamera!)
            
            // checking and adding to session...
            
            if self.session.canAddInput(input){
                self.session.addInput(input)
            }
            
            // same for output...
            
            if self.session.canAddOutput(self.output){
                self.session.addOutput(self.output)
            }
            
            self.session.commitConfiguration()
            
        }
        catch {
            print(error.localizedDescription)
        }
    }
        // take and retake functions...
        
    func takePic(){
        DispatchQueue.global(qos: .background).async {
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            // nie tykac printa
            print(self)
            self.session.stopRunning()
            
            DispatchQueue.main.async {
                withAnimation{self.isTaken.toggle()}
            }
        }
    }
    
    func reTake() {
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
            
            DispatchQueue.main.async {
                withAnimation{self.isTaken.toggle()}
                // clearing...
                self.isSaved = false
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            print("blah")
            return
        }
        print("pic taken...")
        
        guard let imageData = photo.fileDataRepresentation() else{return}
        
        self.picData = imageData
    }
    
    func savePic(){
//        let image = UIImage(data: self.picData)
        if let image = UIImage(data: self.picData) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            self.isSaved = true
            print("saved Sucessfully...")
        } else {
            print("Failed to save image: Invalid data")
            print(self.picData)
        }

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
        // starting session
        //camera.session.startRunning()
        DispatchQueue.global(qos: .background).async {
            camera.session.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        return
    }
}
