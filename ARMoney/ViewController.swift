/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import SceneKit
import UIKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var totalAmount: UILabel!
    @IBOutlet weak var totalBackground: UIView!
    @IBOutlet weak var blurView: UIVisualEffectView!
    var totalAmountTimer : Timer!
    let synthesizer = AVSpeechSynthesizer()
    
    var enableVoiceOver = true; // disable voice over with this
    
    var subTotal = CurrencyPrice(currency: "USD", foreignAmount:0, amount:0, country: "United States", friendlyCurrency: "US Dollars")
    
    /// The view controller that displays the status and "restart experience" UI.
    lazy var statusViewController: StatusViewController = {
        return childViewControllers.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()
    
    @IBAction func restartPressed(_ sender: Any) {
        print("restart pressed")
        
        restartExperience()
    }
    
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! +
        ".serialSceneKitQueue")
    
    var session: ARSession {
        return sceneView.session
    }
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.isJitteringEnabled = true
        
        sceneView.debugOptions = [
            // .showSomething
        ]
    
        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Prevent the screen from being dimmed to avoid interuppting the AR experience.
		UIApplication.shared.isIdleTimerDisabled = true

        // Start the AR experience
        resetTracking()
	}
	

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

        session.pause()
	}

    // MARK: - Session management (Image detection setup)
    
    /// Prevents restarting the session while a restart is in progress.
    var isRestartAvailable = true

    
    func createARPlanePhysics(geometry: SCNGeometry) -> SCNPhysicsBody {
        let physicsBody = SCNPhysicsBody(
            type: .kinematic,
            shape: SCNPhysicsShape(geometry: geometry,
                                   options: nil))
        physicsBody.restitution = 0.5
        physicsBody.friction = 0.5
        return physicsBody
    }
    
    /// Creates a new AR configuration to run on the `session`.
    /// - Tag: ARReferenceImage-Loading
	func resetTracking() {
        
        hideAndResetTotalCard()
        
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Money", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
    
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = referenceImages
        if #available(iOS 12.0, *) {            
            configuration.maximumNumberOfTrackedImages = 15
            configuration.isLightEstimationEnabled = true
        } else {
            // No tracking below 12
        }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        statusViewController.scheduleMessage("Look around to find money", inSeconds: 7.5, messageType: .contentPlacement)
	}

    
    
    // MARK: - ARSCNViewDelegate (Image detection results)
    
    /// - Tag: ARImageAnchor-Visualizing
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        
        updateQueue.async {
            // Create a plane for the detected note
            let plane = SCNPlane(width: referenceImage.physicalSize.width,
                                 height: referenceImage.physicalSize.height)
            let planeNode = SCNNode(geometry: plane)
            planeNode.opacity = 1
            let maskMaterial = SCNMaterial()
            maskMaterial.diffuse.contents = UIColor.white
            maskMaterial.colorBufferWriteMask = SCNColorMask(rawValue: 0) // make it invisible but occluding
            maskMaterial.isDoubleSided = false
            planeNode.geometry?.firstMaterial = maskMaterial
            
            planeNode.eulerAngles.x = -.pi / 2

            let imageName = referenceImage.name ?? "[don't know which]"
            node.name = imageName

            planeNode.renderingOrder = -1
            planeNode.geometry?.firstMaterial?.readsFromDepthBuffer = false

            node.addChildNode(planeNode)            
 
            let anchorNode = SCNScene(named: "art.scnassets/currency.scn")!.rootNode.childNodes[0]
            
            let converter = CurrencyConverter()
            let converted = converter.convert(fromImageName: imageName, targetCurrency: "USD")
            
            if let textGeometry = anchorNode.childNodes[0].geometry as? SCNText {
                textGeometry.string = "\(converted.formattedAmount)"
            }
            
            if let textGeometry = anchorNode.childNodes[1].geometry as? SCNText {
                textGeometry.string = "\(converted.country)"
            }
            
            
            if let tubeNode = anchorNode.childNodes[2] as? SCNNode {
                let graphHeight = Float(converted.amount) * 0.3 // height multiplier
                tubeNode.pivot = SCNMatrix4MakeTranslation(0.0, -(graphHeight/2), 0.0)
                if let tubeGeometry = tubeNode.geometry as? SCNTube {
//                    let action = SCNAction.scale(to: CGFloat(graphHeight), duration: 0.4)
//                    tubeNode.runAction(action)
                    tubeGeometry.height = CGFloat(graphHeight)
            }
            }
            

            anchorNode.opacity = 0.9 // occlusion only works with != 1.0 opacity!
            node.addChildNode(anchorNode)
            
            // update the total field at the bottom of the screen
            self.subTotal.amount = self.subTotal.amount + converted.amount;
            DispatchQueue.main.async {
                print("totalbackground is hidden: \(self.totalBackground.isHidden)")
                self.updateTotalCard(withPrice: self.subTotal)
                self.speak(s: "\(Int(converted.foreignAmount)) " + converted.friendlyCurrency)
                
                if self.totalAmountTimer != nil {
                    self.totalAmountTimer.invalidate()
                }
                
                self.totalAmountTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false, block: { (tot) in
                    print("Scheduling a spoken total")
                    
                    self.speak(s: "The total is \(Int(self.subTotal.amount)) \(self.subTotal.friendlyCurrency)")
                })
            }
        }

        DispatchQueue.main.async {
            let imageName = referenceImage.name ?? ""
            self.statusViewController.cancelAllScheduledMessages()
            self.statusViewController.showMessage("Detected image “\(imageName)” ")
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // is it an imageanchor
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage

        updateQueue.async {
            // grab the planenode we added above
            let planeNode = node.childNodes[0]
            let p = planeNode.geometry as! SCNPlane
            p.width = referenceImage.physicalSize.width
            p.height = referenceImage.physicalSize.height
            p.firstMaterial?.ambientOcclusion.contents = 1
//            print("Did update node for \(planeNode.name ?? "[no name]") to x = \(node.position.x)")
        }
    }
    
    func speak(s:String){
        if !enableVoiceOver { return }
        
        let voices = AVSpeechSynthesisVoice.speechVoices()
        print(voices)
        var voiceToUse: AVSpeechSynthesisVoice?
        
        for voice in voices {
            if voice.name == "Aaron" {
                voiceToUse = voice
                print("Aaron")
            }
        }
    
        print("Speaking \(s)")
        let utterance = AVSpeechUtterance(string: s)
        utterance.voice = voiceToUse
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
    
    func showTotalCard(){
        totalBackground.center.y += totalBackground.frame.height
        totalBackground.isHidden = false
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut , animations: {
            self.totalBackground.center.y -= self.totalBackground.frame.height
        }, completion: nil)
    }
    
    func hideAndResetTotalCard(){
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut , animations: {
            self.totalBackground.center.y += self.totalBackground.frame.height
        }, completion: {(void) in
            self.totalBackground.isHidden = true
            self.subTotal.amount = 0
        })
    }
    
    func updateTotalCard(withPrice price : CurrencyPrice){
        let formattedTotal = CurrencyConverter().format(amount: price.amount, currency: price.currency)
        if totalBackground.isHidden {
            totalAmount.text = formattedTotal // set text
            showTotalCard()
        } else { // card already up
            self.totalAmount.text = formattedTotal
        }
    }

    var imageHighlightAction: SCNAction {
        return .sequence([
            .wait(duration: 1.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOpacity(to: 0.15, duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOut(duration: 0.5),
//            .removeFromParentNode()
        ])
    }
    
    // MARK: Plane Helpers
    // TODO: Add AddARPlane
    
    // TODO: add update ARPlanenode
    
    
}
