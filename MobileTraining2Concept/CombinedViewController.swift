//
//  CombinedViewController.swift
//  MobileTraining2Concept
//
//  Created by Lukas Schmidt on 30.09.19.
//  Copyright © 2019 Lukas Schmidt. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

enum CombinedState {
    case flying, building
}

class CombinedViewController: UIViewController, ARSCNViewDelegate {
    
    
        
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var placeItemButton: UIButton!
    
    // Containers to allow easy hiding and showing of the controls for each mode.
    @IBOutlet weak var builderControlContainer: UIView!
    @IBOutlet weak var droneControlContainer: UIView!
    
    // Flying Controls
    @IBOutlet weak var joystickLeft: JoystickView!
    @IBOutlet weak var joystickRight: JoystickView!
    
    var shipNode: SCNNode!

    
    // MARK: State
    
    /// Whether we are building or flying
    var mode: CombinedState = .building {
        didSet {
            modeChanged()
        }
    }
    
    /// This stores a reference to the node we currently hold.
    var heldObjectNode: SCNNode? {
        didSet {
            updatePlaceItemButtonDescription()
        }
    }
    
    /// This is a reference to the node that is currently targeted.
    var targetedNode: SCNNode? {
        didSet {
            updatePlaceItemButtonDescription()
        }
    }
    /// We need to keep this to restore the appearance of any node to its
    /// previous state.
    var oldTargetMaterial: Any?
    
    // We need to keep a reference to this because if it leaves scope, it is deactivated.
    var timer: Timer!
    
    
    // MARK: Auxiliary variable & Constants
    
    /// This is the node that we add all objects to, so we
    /// can just add this node to another scene to get our own level.
    var worldNode: SCNNode!
    
    // We need this here so we can use it during rendering.
    // Directly using sceneView.bounds.center is not allowed from a background thread.
    var sceneCenter: CGPoint!
    
    // How often to read from the joysticks.
    var updateTimeInterval = 1.0 / 30.0
    
    
    // Mark: View Controller Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        sceneView.scene.physicsWorld.gravity = SCNVector3(0, 0, 0)
        // sceneView.debugOptions = [.showFeaturePoints, .showWorldOrigin]
        sceneView.showsStatistics = false
        
        updatePlaceItemButtonDescription()
        
        worldNode = SCNNode()
        sceneView.scene.rootNode.addChildNode(worldNode)
        
        addLight()
        self.mode = .building
        
        setupFlying()
    }
    

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // configuration.planeDetection = [.horizontal]
        
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func viewDidLayoutSubviews() {
        sceneCenter = sceneView.bounds.center
    }
    
    

    
    // MARK: Setup & State Changes
    
    func setupFlying(){
        // Find our ship
        shipNode = sceneView.scene.rootNode.childNode(withName: "ship", recursively: false)
        shipNode.position = SCNVector3(0, 0, -1)
        shipNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: SCNSphere(radius: 0.5), options: nil))
        shipNode.physicsBody?.damping = 0.8
        shipNode.physicsBody?.angularDamping = 0.8
        shipNode.childNodes.first!.eulerAngles.y = .pi
        shipNode.childNodes.first!.scale = SCNVector3(0.01, 0.01, 0.01)
        
        timer = Timer.scheduledTimer(withTimeInterval: updateTimeInterval, repeats: true) { (timer) in
            self.moveShip()
        }
    }
    
    
    @IBAction func modeChooserChanged(_ sender: Any) {
        self.mode = (sender as! UISegmentedControl).selectedSegmentIndex == 0 ? .building : .flying
    }
    
    func modeChanged() {
        switch mode {
        case .building:
            droneControlContainer.isHidden = true
            builderControlContainer.isHidden = false
        case.flying:
            droneControlContainer.isHidden = false
            builderControlContainer.isHidden = true
        }
    }
    
    // MARK: - Ship interaction

    @IBAction func resetButtonPressed(_ sender: Any) {
        shipNode.physicsBody!.clearAllForces()
        shipNode.position = SCNVector3(0, 0, 0)
    }
    
    func moveShip(){
        let forceScale: Float = 200 * Float(updateTimeInterval)
        shipNode.physicsBody!.applyTorque(
            // That's maybe a quarternion (I think - the documentation seems to think
            // this should be a SCNVector3)
            // Left joystick right/left controls the turning velocity.
            SCNVector4Make(0, -joystickLeft.value.0, 0, 1.0),
            asImpulse: false)
        
        // Right joystick right/left controls right-/leftward motion
        let x = joystickRight.value.0 * forceScale
        // Right joystick up/down controls forward/backward motion
        let z = joystickRight.value.1 * forceScale
        // Left joystick up/down controls up-/downward motion.
        let y = -joystickLeft.value.1 * forceScale * 0.5
        
        // We express this force in the local coordinate system of our spaceship,
        let localForce = SCNVector3(x, y, z)
        // and then transform this to global coordinates before applying it.
        let globalForce = shipNode.presentation.convertVector(localForce, to: sceneView.scene.rootNode)
        shipNode.physicsBody!.applyForce(
            globalForce,
            asImpulse: false)
    }
    
    // MARK: Builder Interaction
    
    @IBAction func addButtonPressed(_ sender: Any){
        guard heldObjectNode == nil else { return }
        
        // let boxGeometry = SCNBox(width: 0.25, height: 0.25, length: 0.25, chamferRadius: 0.01)
        let torusGeometry = SCNTorus(ringRadius: 0.5, pipeRadius: 0.05)
        let node = SCNNode(geometry: torusGeometry)
        
        node.geometry!.firstMaterial!.diffuse.contents = UIColor.blue.withAlphaComponent(0.8)
        node.position = SCNVector3(0, 0, -1.5)
        node.eulerAngles.x = 2 * .pi / 4
        // boxNode.eulerAngles.y = .pi / 4
        sceneView.pointOfView?.addChildNode(node)
        
        heldObjectNode = node
    }
    
    @IBAction func placeItemButtonPressed(_ sender: Any) {
        
        if let heldObjectNode = heldObjectNode {
            // Place node if we have one.
            let heldObjectPosition = heldObjectNode.worldTransform
            heldObjectNode.transform = heldObjectPosition
            heldObjectNode.removeFromParentNode()
            heldObjectNode.geometry!.firstMaterial!.diffuse.contents = UIColor.white
            worldNode.addChildNode(heldObjectNode)
            self.heldObjectNode = nil
        } else {
            // Pick up a node if we don't hold one currently.
            if let targetedNode = targetedNode {
                self.heldObjectNode = targetedNode
                targetedNode.transform = sceneView.pointOfView!.convertTransform(targetedNode.transform, from: worldNode)
                targetedNode.removeFromParentNode()
                sceneView.pointOfView!.addChildNode(targetedNode)
            }
        }
        
    }
    
    
    func addLight(){
        let lightNode = SCNNode()
        lightNode.position = SCNVector3(0, 10, 0)
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        sceneView.scene.rootNode.addChildNode(lightNode)
    }
    
    func updatePlaceItemButtonDescription(){
        DispatchQueue.main.async {
            self.placeItemButton.isEnabled = true
            if self.heldObjectNode != nil {
                self.placeItemButton.setTitle("Place Item", for: .normal)
            } else if self.targetedNode != nil {
                self.placeItemButton.setTitle("Pick Item", for: .normal)
            } else {
                self.placeItemButton.isEnabled = false
            }
        }
    }
}

extension CombinedViewController {
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        targetedNode?.geometry?.firstMaterial?.diffuse.contents = oldTargetMaterial
        
        let hitresults = renderer.hitTest(sceneCenter, options: nil)
        if let hitresult = hitresults.first {
            if self.targetedNode != hitresult.node {
                self.targetedNode = hitresult.node
                self.oldTargetMaterial = self.targetedNode!.geometry!.firstMaterial!.diffuse.contents
            }
            self.targetedNode!.geometry!.firstMaterial!.diffuse.contents = UIColor.red
        } else {
            targetedNode = nil
        }
    }
}

// MARK: - ARSCNViewDelegate

extension CombinedViewController {
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
