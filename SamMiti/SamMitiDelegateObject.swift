//
//  SamMitiDelegateObject.swift
//  SamMitiAR
//
//  Created by Nattawut Singhchai on 1/2/18.
//  Copyright © 2018 Prolific Interactive. All rights reserved.
//

import ARKit

class SamMitiDelegateObject: NSObject, ARSCNViewDelegate, ARSessionDelegate {

    /// A serial queue used to coordinate adding or removing nodes from the scene.
    let updateQueue = DispatchQueue(label: "com.prolificinteractive.com.samMitiAR.serialSceneKitQueue")

    var showAnchorPlane = false

    weak var sceneView: SamMitiARView?

    var updateSession: ((_ frame: ARFrame, _ trackingState: ARCamera.TrackingState) -> Void)?

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSession?(frame, frame.camera.trackingState)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSession?(frame, frame.camera.trackingState)
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSession?(session.currentFrame!, camera.trackingState)
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updateSession?(session.currentFrame!, frame.camera.trackingState)
    }

    /// - Tag: PlaceARContent
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {

        updateQueue.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                
                if let isAdjustOntoPlaneAnchorEnabled =  self.sceneView?.isAdjustOntoPlaneAnchorEnabled {
                    if isAdjustOntoPlaneAnchorEnabled {
                        self.sceneView?.placedVirtualObjects.forEach { $0.adjustOntoPlaneAnchor(planeAnchor, using: node) }
                    }
                }

                // Place content only for anchors found by plane detection.
                if self.showAnchorPlane {
                    guard let device = MTLCreateSystemDefaultDevice(),
                        let anchorGeometry = ARSCNPlaneGeometry(device: device) else { return }
                    anchorGeometry.update(from: planeAnchor.geometry)
                    node.opacity = 0.25
                    node.geometry = anchorGeometry
                }
            } else {
                if let objectAtAnchor = self.sceneView?.placedVirtualObjects.first(where: { $0.anchor == anchor }) {
                    objectAtAnchor.simdPosition = anchor.transform.translation
                    objectAtAnchor.anchor = anchor
                }
            }
        }

    }

    /// - Tag: UpdateARContent
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Place content only for anchors found by plane detection.
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

        let weakSelf = self
        if let isAdjustOntoPlaneAnchorEnabled =  weakSelf.sceneView?.isAdjustOntoPlaneAnchorEnabled {
            if isAdjustOntoPlaneAnchorEnabled {
                updateQueue.async {
                    weakSelf.sceneView?.placedVirtualObjects.forEach { $0.adjustOntoPlaneAnchor(planeAnchor, using: node) }
                }
            }
        }
        

        if showAnchorPlane {
            guard let anchorGeometry = node.geometry as? ARSCNPlaneGeometry else { return }
            anchorGeometry.update(from: planeAnchor.geometry)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.sceneView?.updateObjectToCurrentTrackingPosition()
        }
    }

}
