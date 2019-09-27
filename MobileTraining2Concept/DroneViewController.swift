//
//  ViewController.swift
//  MobileTraining2Concept
//
//  Created by Lukas Schmidt on 01.08.19.
//  Copyright © 2019 Lukas Schmidt. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class DroneViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var joystickLeft: JoystickView!
    @IBOutlet weak var joystickRight: JoystickView!
    
    var shipNode: SCNNode!
    
    // We need to keep a reference to this because if it leaves scope, it is deactivated.
    var timer: Timer!
    
    // How often to read from the joysticks.
    var updateTimeInterval = 1.0 / 30.0
    
    var worldNode: SCNNode?
    
    // MARK: - Lifecycle and Setup
    
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
        sceneView.debugOptions = [.showFeaturePoints, .showWorldOrigin]
        
        // Find our ship
        findAndAdjustShip()
        
        
        timer = Timer.scheduledTimer(withTimeInterval: updateTimeInterval, repeats: true) { (timer) in
            self.moveShip()
        }
        
        for viewController in self.tabBarController?.viewControllers ?? [] {
            if viewController is BuilderViewController {
                (viewController as? BuilderViewController)?.delegate = self
            }
        }
        
        addLight()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func findAndAdjustShip(){
        shipNode = sceneView.scene.rootNode.childNode(withName: "ship", recursively: false)
        shipNode.position = SCNVector3(0, 0, -1)
        shipNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: SCNSphere(radius: 0.5), options: nil))
        shipNode.physicsBody?.damping = 0.8
        shipNode.physicsBody?.angularDamping = 0.8
        shipNode.childNodes.first!.eulerAngles.y = .pi
        shipNode.childNodes.first!.scale = SCNVector3(0.01, 0.01, 0.01)
    }


    
    // MARK: - Actions
    
    @IBAction func joystickLeftMoved(_ sender: Any) {
        //moveShip()
    }
    
    @IBAction func joystickRightMoved(_ sender: Any) {
        // moveShip()
    }
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        shipNode.physicsBody!.clearAllForces()
        shipNode.position = SCNVector3(0, 0, 0)
    }
    
    // MARK: - Ship interaction
    
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
}



// MARK: - Builder Interaction

extension DroneViewController : BuilderDelegate {
    func builderAdded(buildNode: SCNNode) {
        print("Builder added worldnode!")
        self.worldNode = buildNode.flattenedClone()
        if let worldNode = worldNode {
            self.sceneView.scene.rootNode.addChildNode(worldNode)
        }
    }
    
    func builderChanged(buildNode: SCNNode) {
        // HACK: This is probably wrong; iOS complains that one scene is modified within a rendering callback of another scene.
        self.worldNode?.removeFromParentNode()
        self.worldNode = buildNode.flattenedClone()
        if let worldNode = worldNode {
            self.sceneView.scene.rootNode.addChildNode(worldNode)
        }
    }
}

// MARK: - Plane Detection

extension DroneViewController {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        let plane = SCNPlane(width: width, height: height)
        
        plane.materials.first?.diffuse.contents = UIColor.white.withAlphaComponent(0.5)
        
        var planeNode = SCNNode(geometry: plane)
        
        planeNode.position = SCNVector3(planeAnchor.center)
        planeNode.eulerAngles.x = -.pi / 2
        
        update(&planeNode, withGeometry: plane, type: .static)
        
        node.addChildNode(planeNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            var planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        plane.width = width
        plane.height = height
        
        planeNode.position = SCNVector3(planeAnchor.center)
        
        update(&planeNode, withGeometry: plane, type: .static)
    }
    
    
    func update(_ node: inout SCNNode, withGeometry geometry: SCNGeometry, type: SCNPhysicsBodyType) {
        // This adds physics bodies to planes, to enable collisions with the environment.
        // It's not active because the plane detection is not really reliable enough.
        // let shape = SCNPhysicsShape(geometry: geometry, options: nil)
        // let physicsBody = SCNPhysicsBody(type: type, shape: shape)
        // node.physicsBody = physicsBody
    }
}


// MARK: - Utilities

extension DroneViewController {
    func addLight(){
        let lightNode = SCNNode()
        lightNode.position = SCNVector3(0, 10, 0)
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        sceneView.scene.rootNode.addChildNode(lightNode)
    }
    
    func getBloomFilter() -> [CIFilter]? {
        let bloomFilter = CIFilter(name:"CIBloom")!
        bloomFilter.setValue(10.0, forKey: "inputIntensity")
        bloomFilter.setValue(30.0, forKey: "inputRadius")
        
        return [bloomFilter]
    }
}

// MARK: - ARSCNViewDelegate

extension DroneViewController {
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
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
