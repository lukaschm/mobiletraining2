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

class BuilderViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var joystickLeft: JoystickView!
    @IBOutlet weak var joystickRight: JoystickView!
    @IBOutlet weak var placeItemButton: UIButton!

    var shipNode: SCNNode!
    
    var heldObjectNode: SCNNode? {
        didSet {
            updatePlaceItemButtonDescription()
        }
    }
    
    var targetedNode: SCNNode? {
        didSet {
            updatePlaceItemButtonDescription()
        }
    }
    var oldTargetMaterial: Any?
    
    var timer: Timer!
    
    var updateTimeInterval = 1.0 / 30.0
    
    // We need this here so we can use it during rendering.
    // Directly using sceneView.bounds.center is not allowed from a background thread.
    var sceneCenter: CGPoint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        sceneView.scene.physicsWorld.gravity = SCNVector3(0, 0, 0)
        // sceneView.debugOptions = [.showFeaturePoints, .showWorldOrigin]
        sceneView.showsStatistics = false
        
        updatePlaceItemButtonDescription()
        
        addLight()
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

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    override func viewDidLayoutSubviews() {
        sceneCenter = sceneView.bounds.center
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
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
            // Place Item if we have one.
            let heldObjectPosition = heldObjectNode.worldTransform
            heldObjectNode.transform = heldObjectPosition
            heldObjectNode.removeFromParentNode()
            heldObjectNode.geometry!.firstMaterial!.diffuse.contents = UIColor.white
            sceneView.scene.rootNode.addChildNode(heldObjectNode)
            self.heldObjectNode = nil
        } else {
            // Pick up Item if we don't hold one currently.
            if let targetedNode = targetedNode {
                self.heldObjectNode = targetedNode
                targetedNode.transform = sceneView.pointOfView!.convertTransform(targetedNode.transform, from: sceneView.scene.rootNode)
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

extension BuilderViewController {
    
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
    
    // MARK: - Plane detection
    
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
