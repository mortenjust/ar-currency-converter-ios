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
    
    var subTotal : Double = 0
    
    /// The view controller that displays the status and "restart experience" UI.
    lazy var statusViewController: StatusViewController = {
        return childViewControllers.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()
    
    /// A serial queue for thread safety when modifying the SceneKit node graph.
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! +
        ".serialSceneKitQueue")
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DispatchQueue.main.async {
            self.totalBackground.center.y += self.totalBackground.frame.height
        }
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.isJitteringEnabled = true

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

    /// Creates a new AR configuration to run on the `session`.
    /// - Tag: ARReferenceImage-Loading
	func resetTracking() {
        
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Money", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = referenceImages
        if #available(iOS 12.0, *) {            
            configuration.maximumNumberOfTrackedImages = 5
        } else {
            // No tracking below 12
        }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        statusViewController.scheduleMessage("Look around to detect images", inSeconds: 7.5, messageType: .contentPlacement)
	}

    
    
    // MARK: - ARSCNViewDelegate (Image detection results)
    
    /// - Tag: ARImageAnchor-Visualizing
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        
        
        updateQueue.async {
            // Create a plane to visualize the initial position of the detected image.
            let plane = SCNPlane(width: referenceImage.physicalSize.width,
                                 height: referenceImage.physicalSize.height)
            let planeNode = SCNNode(geometry: plane)
            planeNode.opacity = 0.01

            /*
             `SCNPlane` is vertically oriented in its local coordinate space, but
             `ARImageAnchor` assumes the image is horizontal in its local space, so
             rotate the plane to match.
             */
            planeNode.eulerAngles.x = -.pi / 2
            
            /*
             Image anchors are not tracked after initial detection, so create an
             animation that limits the duration for which the plane visualization appears.
             */
            
            // planeNode.runAction(self.imageHighlightAction)
            
            // Add the plane visualization to the scene.
            let imageName = referenceImage.name ?? "[don't know which]"
            node.name = imageName
            
            node.addChildNode(planeNode)            
            
            // grab rootnode
            let anchorNode = SCNScene(named: "art.scnassets/currency.scn")!.rootNode.childNodes[0]
            
            // grab the text node and change it
            let converter = CurrencyConverter()
            if let textGeometry = anchorNode.childNodes[0].geometry as? SCNText {
                let a = converter.convert(fromImageName: imageName, targetCurrency: "USD")
                textGeometry.string = "\(a.formattedAmount)"
                self.subTotal = self.subTotal + a.amount;
                
                // update the total field at the bottom of the screen
                DispatchQueue.main.async {
                    self.totalAmount.text = "\(a.formattedAmount)";
                    if self.totalBackground.isHidden {
                        self.totalBackground.isHidden = false
                        UIView.animate(withDuration: 1.3, delay: 0, options: .curveEaseOut , animations: {
                            self.totalBackground.center.y -= self.totalBackground.frame.height
                        }, completion: nil)
                    }
                }
            }
            node.addChildNode(anchorNode)

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
//            print("Did update node for \(planeNode.name ?? "[no name]") to x = \(node.position.x)")
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
