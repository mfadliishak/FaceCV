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
    var lastGazeIndex = kGAZE_INDEX_NONE
    var gazeIndex = kGAZE_INDEX_NONE
    var blinkCounter = 0
    var stareCounter:Float = 0.0; //
    weak var stareTimer: Timer?
    
    let selectionTime = 2 //seconds
    let defaultDuration = 2.0
    let defaultDamping = 0.20
    let defaultVelocity = 3.0

    @IBOutlet weak var cameraViewImage: UIImageView!
    @IBOutlet weak var labelStatus: UILabel!
    @IBOutlet weak var rightButton: UIButton!
    @IBOutlet weak var centerButton: UIButton!
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var selectProgressView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        sessionHandler = SessionHandler();
        sessionHandler?.facialMovementDelegate = self
        
        //pan gesture for dragging an image
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(ViewController.dragImg(_:)))
        cameraViewImage.isUserInteractionEnabled = true
        cameraViewImage.addGestureRecognizer(panGesture)
        self.resetProgress()
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
    
    func resetProgress() {
        DispatchQueue.main.async {
            self.selectProgressView.progress = 0.0
            self.selectProgressView.isHidden = true
            self.stareTimer?.invalidate()
        }
        self.stareCounter = 0.0
    }
    
    func highlightButton(gazeIndex: Int32) {
        //var percent:Float = 0.0
        var progressFull:Bool = false;
        self.gazeIndex = gazeIndex
        
        if lastGazeIndex != gazeIndex {
            self.resetProgress()
        }
        
        if gazeIndex != kGAZE_INDEX_NONE {
            if self.stareTimer != nil {
                //percent = Float(min(Float(stareCounter) / Float(selectionTime) * 100.0, 100.0))
                
                DispatchQueue.main.async {
                    if self.selectProgressView.progress >= 100.0 {
                        progressFull = true;
                    }
                }
            }
            else {
                DispatchQueue.main.async {
                    let timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.stareRunTimer), userInfo: nil, repeats: true)
                    
                    RunLoop.current.add(timer, forMode: .common)
                    timer.tolerance = 0.1
                    self.stareTimer = timer
                }
            }
        }
        
        DispatchQueue.main.async {
            switch gazeIndex {
            case kGAZE_INDEX_LEFT:
                self.leftButton.isHighlighted = true
                self.leftButton.backgroundColor = UIColor.systemPink
                self.setPositionProgress(x: 50, y: 310)
                if(progressFull) {
                    self.selectButton(button: self.leftButton)
                }
                break;
            case kGAZE_INDEX_RIGHT:
                self.rightButton.isHighlighted = true;
                self.rightButton.backgroundColor = UIColor.systemPink
                self.setPositionProgress(x: 568, y: 310)
                if(progressFull) {
                    self.selectButton(button: self.rightButton)
                }
                break;
            case kGAZE_INDEX_CENTER:
                self.centerButton.isHighlighted = true
                self.centerButton.backgroundColor = UIColor.systemPink
                self.setPositionProgress(x: 309, y: 310)
                if(progressFull) {
                    self.selectButton(button: self.centerButton)
                }
                break;
            default:
                self.resetButtons()
                self.resetProgress()
                break;
            }
        }
        
        lastGazeIndex = gazeIndex
        
        
    }
    
    func setPositionProgress(x: CGFloat, y: CGFloat) {
        DispatchQueue.main.async {
            self.selectProgressView.frame.origin = CGPoint(x:x, y:y)
            if self.selectProgressView.isHidden {
                self.selectProgressView.isHidden = false
            }
        }
    }
    
    func selectButton(button: UIButton) {
        DispatchQueue.main.async {
            button.isSelected = true
        }
    }
    
    @objc func stareRunTimer() {
        self.stareCounter += 0.1
        print("ssss")
        
        self.selectProgressView.setProgress(self.stareCounter / Float(self.selectionTime), animated: true)
        if self.stareCounter >= Float(self.selectionTime) {
            buttonSelectedAction()
            self.resetProgress()
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
    
    func buttonSelectedAction() {
        switch gazeIndex {
        case kGAZE_INDEX_LEFT:
            self.animateButton(button: self.leftButton)
            break;
        case kGAZE_INDEX_RIGHT:
            self.animateButton(button: self.rightButton)
            break;
        case kGAZE_INDEX_CENTER:
            self.animateButton(button: self.centerButton)
            break;
        default:
            break;
        }
    }
    
    func animateButton(button:UIButton) {
        self.view.bringSubviewToFront(button)
        button.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)

        UIView.animate(withDuration: defaultDuration,
            delay: 0,
            usingSpringWithDamping: CGFloat(defaultDamping),
            initialSpringVelocity: CGFloat(defaultVelocity),
            options: .allowUserInteraction,
            animations: {
                button.transform = .identity
            },
            completion: { finished in
                
            })
    }

}

