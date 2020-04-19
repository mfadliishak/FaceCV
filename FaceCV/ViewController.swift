//
//  ViewController.swift
//  FaceCV
//
//  Created by Fadli Ishak on 2020/04/18.
//  Copyright © 2020 Fadli Ishak. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController  {
    
    let sessionHandler = SessionHandler()

    @IBOutlet weak var cameraViewImage: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        sessionHandler.openSession()

        let layer = sessionHandler.layer
        layer.frame = cameraViewImage.bounds
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        layer.needsDisplayOnBoundsChange = true
        
        cameraViewImage.layer.addSublayer(layer)
        
        view.layoutIfNeeded()

    }

    
    func setImageViewLayout(preset: AVCaptureSession.Preset){
        let width = self.view.frame.width
        var height:CGFloat
        switch preset {
        case .photo:
            height = width * 852 / 640
        case .high:
            height = width * 1280 / 720
        case .medium:
            height = width * 480 / 360
        case .low:
            height = width * 192 / 144
        case .cif352x288:
            height = width * 352 / 288
        case .hd1280x720:
            height = width * 1280 / 720
        default:
            height = self.view.frame.height
        }
        cameraViewImage.frame = CGRect(x: 0, y: 0, width: width, height: height)
    }

}

