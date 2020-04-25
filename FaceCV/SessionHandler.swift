//
//  SessionHandler.swift
//  DisplayLiveSamples
//
//  Created by Luis Reisewitz on 15.05.16.
//  Copyright © 2016 ZweiGraf. All rights reserved.
//

import AVFoundation

protocol FacialMovementDelegate: class {
    func eyeTrackingAction(_ isBlink: Bool, faceIndex: Int32?, gazeIndex: Int32)
}

class SessionHandler : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate {
    var session = AVCaptureSession()
    let layer = AVSampleBufferDisplayLayer()
    let sampleQueue = DispatchQueue(label: "com.zweigraf.DisplayLiveSamples.sampleQueue", attributes: [])
    let faceQueue = DispatchQueue(label: "com.zweigraf.DisplayLiveSamples.faceQueue", attributes: [])
    let wrapper = DlibWrapper()
    
    var currentMetadata: [AnyObject]
    weak var facialMovementDelegate:FacialMovementDelegate?
    
    
    override init() {
        currentMetadata = []
        super.init()
    }
    
    func openSession() {
        //let frame = CMTimeMake(value: 1, timescale: 20) //フレームレート
        let position = AVCaptureDevice.Position.front //フロントカメラかバックカメラか
        
        let device = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                                             for: AVMediaType.video,
                                             position: position)!
        
        let input = try! AVCaptureDeviceInput(device: device)
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        
        let connection = output.connection(with: AVMediaType.video)
        connection?.videoOrientation = .portrait
        
        let metaOutput = AVCaptureMetadataOutput()
        metaOutput.setMetadataObjectsDelegate(self, queue: faceQueue)
    
        session.beginConfiguration()
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        if session.canAddOutput(metaOutput) {
            session.addOutput(metaOutput)
        }
        
        // カメラの向きを合わせる
        for connection in output.connections {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = AVCaptureVideoOrientation.portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
        
        session.commitConfiguration()
        
        let settings: [AnyHashable: Any] = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
        output.videoSettings = settings as! [String : Any]
    
        // availableMetadataObjectTypes change when output is added to session.
        // before it is added, availableMetadataObjectTypes is empty
        metaOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.face]
        
        wrapper?.prepare()
        
        session.startRunning()
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        if !currentMetadata.isEmpty {
            let boundsArray = currentMetadata
                .flatMap { $0 as? AVMetadataFaceObject }
                .map { (faceObject) -> NSValue in
                    let convertedObject = output.transformedMetadataObject(for: faceObject, connection: connection)
                    return NSValue(cgRect: convertedObject!.bounds)
            }
            
            wrapper?.doWork(on: sampleBuffer, inRects: boundsArray)
        }

        layer.enqueue(sampleBuffer)
        
        let faceIndex = wrapper?.faceIndex ?? -1
        let blinked = wrapper?.isBlink ?? false
        let gazeIndex = wrapper?.gazeIndex ?? -1;
        facialMovementDelegate?.eyeTrackingAction(blinked, faceIndex: faceIndex, gazeIndex: gazeIndex)
        
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //print("DidDropSampleBuffer")
    }
    
    // MARK: AVCaptureMetadataOutputObjectsDelegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        currentMetadata = metadataObjects as [AnyObject]
    }
}
