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

class PlaneViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var joystickLeft: JoystickView!
    @IBOutlet weak var joystickRight: JoystickView!
    
    var shipNode: SCNNode!
    
    var timer: Timer!
    
    var updateTimeInterval = 1.0 / 30.0
    
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

    // MARK: - ARSCNViewDelegate
    
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
    
    func findAndAdjustShip(){
        shipNode = sceneView.scene.rootNode.childNode(withName: "ship", recursively: false)
        shipNode.position = SCNVector3(0, 0, -1)
        shipNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        shipNode.physicsBody?.mass = 1.0
        shipNode.physicsBody?.damping = 0.8
        shipNode.physicsBody?.angularDamping = 0.8
        shipNode.childNodes.first!.eulerAngles.y = .pi
        shipNode.childNodes.first!.scale = SCNVector3(0.01, 0.01, 0.01)
    }
    
    @IBAction func joystickLeftMoved(_ sender: Any) {
        //moveShip()
    }
    
    @IBAction func joystickRightMoved(_ sender: Any) {
        // moveShip()
    }
    
    func moveShip(){
        let forceScale: Float = 200 * Float(updateTimeInterval)
        shipNode.physicsBody!.applyTorque(
            SCNVector4Make(0, -joystickLeft.value.0, 0, 1.0),
            asImpulse: false)
        
        
        let x = joystickRight.value.0 * forceScale
        let z = joystickRight.value.1 * forceScale
        
        let y = -joystickLeft.value.1 * forceScale
        
        let localForce = SCNVector3(x, y, z)
        let globalForce = shipNode.presentation.convertVector(localForce, to: sceneView.scene.rootNode)
        
        let force = SCNVector3(globalForce.x, globalForce.y * 0.5, globalForce.z)
        
        shipNode.physicsBody!.applyForce(
            force,
            asImpulse: false)
    }
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        shipNode.physicsBody!.clearAllForces()
        shipNode.position = SCNVector3(0, 0, 0)
    }
}

extension PlaneViewController {
    
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
        let shape = SCNPhysicsShape(geometry: geometry, options: nil)
        let physicsBody = SCNPhysicsBody(type: type, shape: shape)
        node.physicsBody = physicsBody
    }
}
