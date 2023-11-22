//
//  UploadPhotos.swift
//  Roll
//
//  Created by Zane Sabbagh on 11/19/23.
//

import UIKit
import Photos
import FirebaseStorage
import FirebaseFirestore

class PhotoUploader {

    let storageRef = Storage.storage().reference()
    let firestoreDb = Firestore.firestore()
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    func uploadImagesFromCameraRoll() {
        // Request access to the camera roll
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                print("Need access to upload images")
                return
            }
            
            let documentRef = self?.firestoreDb.collection("photos").document("zane")
            documentRef?.getDocument { [weak self] (document, error) in
                if let document = document, document.exists {
                    let dataDescription = document.data().map(String.init(describing:)) ?? "nil"
                    print("Document data: \(dataDescription)")
                    
                    var earliestTimestamp = document.data()?["earliestTimestamp"] as? Timestamp ?? Timestamp(date: Date())
                    var latestTimestamp = document.data()?["latestTimestamp"] as? Timestamp ?? Timestamp(date: Date(timeIntervalSince1970: 0))
                    
                    self?.beginBackgroundUpdateTask()
                    
                    // Fetch the assets
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                    let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                    var uploadCount = 0

                    assets.enumerateObjects { (asset, index, stop) in
                        // For each asset, get the image
                        let manager = PHImageManager.default()
                        let options = PHImageRequestOptions()
                        options.isSynchronous = true
                        options.deliveryMode = .highQualityFormat
                        manager.requestImageData(for: asset, options: options) { [weak self] data, _, _, _ in
                            guard let self = self, let data = data else { return }
                            
                            // Extract timestamp and location metadata
                            let timestamp = asset.creationDate ?? Date()
                            let location = asset.location
                            
                            // Create a unique file name
                            let fileName = UUID().uuidString + ".jpg"
                            let imageRef = self.storageRef.child("photos/zane/\(fileName)")
                            
                            // Upload the image data to Firebase Storage
                            let metadata = StorageMetadata()
                            metadata.contentType = "image/jpeg"
                            imageRef.putData(data, metadata: metadata) { metadata, error in
                                guard let metadata = metadata else {
                                    print("Error uploading image: \(String(describing: error))")
                                    return
                                }

                                // Retrieve the download URL
                                imageRef.downloadURL { [weak self] url, error in
                                    guard let self = self, let downloadURL = url else {
                                        print("Error getting download URL: \(String(describing: error))")
                                        return
                                    }
                                    
                                    uploadCount += 1
                                    print("Uploaded \(uploadCount) images.")

                                    // Create a map to hold the URL, timestamp, and location
                                    var photoMap: [String: Any] = [
                                        "URL": downloadURL.absoluteString,
                                        "timestamp": timestamp
                                    ]
                                    
                                    // If location data is available, add it to the map
                                    if let location = location {
                                        photoMap["location"] = [
                                            "latitude": location.coordinate.latitude,
                                            "longitude": location.coordinate.longitude
                                        ]
                                    }
                                    
                                    // Update the earliest and latest timestamps if necessary
                                    if timestamp < earliestTimestamp.dateValue() {
                                        earliestTimestamp = Timestamp(date: timestamp)
                                    }
                                    if timestamp > latestTimestamp.dateValue() {
                                        latestTimestamp = Timestamp(date: timestamp)
                                    }
                                    
                                    let updateData: [String: Any] = [
                                        "cameraRoll": FieldValue.arrayUnion([photoMap]),
                                        "earliestTimestamp": earliestTimestamp,
                                        "latestTimestamp": latestTimestamp
                                    ]
                                    
                                    // Add the photo map to the 'CameraRoll' array in Firestore and update timestamps
                                    documentRef?.updateData(updateData) { error in
                                        if let error = error {
                                            print("Error adding image metadata to Firestore: \(error)")
                                        } else {
                                            print("Image metadata and timestamps successfully added to Firestore.")
                                        }
                                        
                                        // End the background task if it was the last photo
                                        if uploadCount == assets.count {
                                            self.endBackgroundUpdateTask()
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    print("Document does not exist in Firestore or error fetching document: \(String(describing: error))")
                }
            }
        }
    }
    
    func beginBackgroundUpdateTask() {
        self.backgroundTask = UIApplication.shared.beginBackgroundTask {
            // End the task if time expires.
            self.endBackgroundUpdateTask()
        }
    }

    func endBackgroundUpdateTask() {
        UIApplication.shared.endBackgroundTask(self.backgroundTask)
        self.backgroundTask = .invalid
    }
}
