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


protocol BuilderDelegate {
    func builderAdded(buildNode: SCNNode)
    func builderChanged(buildNode: SCNNode)
}

class BuilderViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var placeItemButton: UIButton!

    var shipNode: SCNNode!
    
    /// This is the node that we add all objects to, so we
    /// can just add this node to another scene to get our own level.
    var worldNode: SCNNode!
    
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
    
    // We need this here so we can use it during rendering.
    // Directly using sceneView.bounds.center is not allowed from a background thread.
    var sceneCenter: CGPoint!
    
    var delegate: BuilderDelegate?
    
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
        
        worldNode = SCNNode()
        sceneView.scene.rootNode.addChildNode(worldNode)
        delegate?.builderAdded(buildNode: worldNode)
        
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
            // Place node if we have one.
            let heldObjectPosition = heldObjectNode.worldTransform
            heldObjectNode.transform = heldObjectPosition
            heldObjectNode.removeFromParentNode()
            heldObjectNode.geometry!.firstMaterial!.diffuse.contents = UIColor.white
            worldNode.addChildNode(heldObjectNode)
            delegate?.builderChanged(buildNode: worldNode)
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
}
