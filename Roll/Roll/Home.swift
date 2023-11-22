//
//  Home.swift
//  Roll
//
//  Created by Zane Sabbagh on 11/19/23.
//

import Foundation
import SwiftUI
import Photos
import Contacts

struct Home: View {
    
    @State private var isCameraRollAccessDenied: Bool = false
    @State private var isContactsAccessDenied: Bool = false
    let photoUploader = PhotoUploader()
    
    var body: some View {
        Text("Request Permissions")
            .onAppear {
                requestCameraRollAccess()
                requestContactsAccess()
            }
            .alert("Camera Roll Access Denied", isPresented: $isCameraRollAccessDenied, actions: {}) {
                Text("Please allow access to your camera roll from the Settings app.")
            }
            .alert("Contacts Access Denied", isPresented: $isContactsAccessDenied, actions: {}) {
                Text("Please allow access to your contacts from the Settings app.")
            }
    }
    
    private func requestCameraRollAccess() {
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized, .limited:
                // Access is granted.
                self.photoUploader.uploadImagesFromCameraRoll()
            case .denied, .restricted:
                // Access is denied.
                isCameraRollAccessDenied = true
            default:
                // Other cases to handle future OS changes.
                break
            }
        }
    }
    
    private func requestContactsAccess() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            if let error = error {
                print("Request contacts access failed with error: \(error).")
                return
            }
            
            if !granted {
                // Access is denied.
                isContactsAccessDenied = true
            }
        }
    }
}
