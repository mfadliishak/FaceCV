//
//  ViewController.swift
//  FaceCV
//
//  Created by Fadli Ishak on 2020/04/18.
//  Copyright © 2020 Fadli Ishak. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, FacialMovementDelegate {
    
    var sessionHandler:SessionHandler? = nil
    var panGesture  = UIPanGestureRecognizer()
    var lastGazeIndex = 0
    var blinkCounter = 0

    @IBOutlet weak var cameraViewImage: UIImageView!
    @IBOutlet weak var labelStatus: UILabel!
    @IBOutlet weak var rightButton: UIButton!
    @IBOutlet weak var centerButton: UIButton!
    @IBOutlet weak var leftButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        sessionHandler = SessionHandler();
        sessionHandler?.facialMovementDelegate = self
        
        //pan gesture for dragging an image
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(ViewController.dragImg(_:)))
        cameraViewImage.isUserInteractionEnabled = true
        cameraViewImage.addGestureRecognizer(panGesture)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        sessionHandler?.openSession()

        let layer = sessionHandler?.layer
        layer?.frame = cameraViewImage.bounds
        layer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        layer?.needsDisplayOnBoundsChange = true
        
        cameraViewImage.layer.addSublayer(layer!)
        
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
    
    func eyeTrackingAction(_ isBlink: Bool, faceIndex: Int32?, gazeIndex: Int32) {
        if isBlink {
            DispatchQueue.main.async {
                self.labelStatus.text = "status:<Blink>"
                //_ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
                //    self.labelStatus.text = "status:<>"
                //}
            }
            
        }
        else {
            DispatchQueue.main.async {
                self.labelStatus.text = "status:<>"
            }
        }
        
        self.resetButtons()
        self.highlightButton(gazeIndex: gazeIndex)
        
    }
    
    func resetButtons() {
        DispatchQueue.main.async {
            self.leftButton.isHighlighted = false;
            self.rightButton.isHighlighted = false;
            self.centerButton.isHighlighted = false;
            
            self.leftButton.backgroundColor = UIColor.systemYellow;
            self.rightButton.backgroundColor = UIColor.systemYellow;
            self.centerButton.backgroundColor = UIColor.systemYellow;
        }
    }
    
    func highlightButton(gazeIndex: Int32) {
        DispatchQueue.main.async {
            switch gazeIndex {
            case kGAZE_INDEX_LEFT:
                self.leftButton.isHighlighted = true;
                self.leftButton.backgroundColor = UIColor.systemPink;
                break;
            case kGAZE_INDEX_RIGHT:
                self.rightButton.isHighlighted = true;
                self.rightButton.backgroundColor = UIColor.systemPink;
                break;
            case kGAZE_INDEX_CENTER:
                self.centerButton.isHighlighted = true;
                self.centerButton.backgroundColor = UIColor.systemPink;
                break;
            default:
                self.resetButtons();
                break;
            }
        }
    }
    
    @objc func dragImg(_ sender:UIPanGestureRecognizer){
        let translation = sender.translation(in: self.view)
        cameraViewImage.center = CGPoint(x: cameraViewImage.center.x + translation.x, y: cameraViewImage.center.y + translation.y)
        sender.setTranslation(CGPoint.zero, in: self.view)
        labelStatus.frame.origin =
            CGPoint(x: cameraViewImage.frame.origin.x,
                    y: cameraViewImage.frame.origin.y + cameraViewImage.frame.height + 20)
    }
    
    @IBAction func scaleImg(_ sender: UIPinchGestureRecognizer) {
       cameraViewImage.transform = CGAffineTransform(scaleX: sender.scale, y: sender.scale)
    }

}

