//
//  FriendRequests.swift
//  Roll
//
//  Created by Zane Sabbagh on 11/20/23.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import SDWebImageSwiftUI // To load images from URLs

struct FriendRequest: Identifiable {
    var id: String
    var from: String
    var to: String
    var status: String
    var timestamp: Timestamp
    var displayName: String
    var profileImage: String
}

class FriendRequestsViewModel: ObservableObject {
    @Published var incomingRequests: [FriendRequest] = []

        @EnvironmentObject var userSession: UserSession // Use the EnvironmentObject
        private var db = Firestore.firestore()
        
        private var currentUserId: String? {
            userSession.documentID // This will retrieve the current user ID from the UserSession EnvironmentObject
        }

    func fetchIncomingRequests() {
        guard let currentUserId = currentUserId else {
            print("Error: currentUserId is nil")
            return
        }
        db.collection("friendRequests")
        .whereField("to", isEqualTo: currentUserId)
        .whereField("status", isEqualTo: "pending")
        .addSnapshotListener { [weak self] querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching incoming requests: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Fetch user details for each incoming request
            let group = DispatchGroup()
            var requests: [FriendRequest] = []
            
            for doc in documents {
                group.enter()
                let data = doc.data()
                let fromUserId = data["from"] as? String ?? ""
                
                self?.db.collection("users").document(fromUserId).getDocument { userSnapshot, userError in
                    guard let userData = userSnapshot?.data() else {
                        print("Error fetching user details: \(userError?.localizedDescription ?? "Unknown error")")
                        group.leave()
                        return
                    }
                    
                    let request = FriendRequest(
                        id: doc.documentID,
                        from: fromUserId,
                        to: data["to"] as? String ?? "",
                        status: data["status"] as? String ?? "",
                        timestamp: data["timestamp"] as? Timestamp ?? Timestamp(),
                        displayName: userData["displayName"] as? String ?? "Unknown",
                        profileImage: userData["profileImage"] as? String ?? ""
                    )
                    requests.append(request)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self?.incomingRequests = requests
            }
        }
    }

    func updateRequestStatus(requestId: String, newStatus: String, fromUserId: String) {
        guard let currentUserId = currentUserId else {
            print("Error: currentUserId is nil")
            return
        }
        
        let requestRef = db.collection("friendRequests").document(requestId)
        let currentUserRef = db.collection("users").document(currentUserId)
        let otherUserRef = db.collection("users").document(fromUserId)

        // Start a batch write
        let batch = db.batch()

        // Update the friend request status
        batch.updateData(["status": newStatus], forDocument: requestRef)

        // If the request is accepted, add each user to the other's 'friends' array
        if newStatus == "accepted" {
            print("Friendship Accepted")
            batch.updateData(["friends": FieldValue.arrayUnion([fromUserId])], forDocument: currentUserRef)
            batch.updateData(["friends": FieldValue.arrayUnion([currentUserId])], forDocument: otherUserRef)
        }

        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("Error updating request status and friends list: \(error.localizedDescription)")
            } else {
                // Handle successful update if necessary, e.g., updating local state
            }
        }
    }
}

struct FriendRequestsView: View {
    @ObservedObject private var viewModel = FriendRequestsViewModel()
    @EnvironmentObject var userSession: UserSession
//    private let currentUserId: String = "FasvaOer4GsX0S5Tnz7T"

    var body: some View {
        NavigationView {
            List(viewModel.incomingRequests) { request in
                HStack {
                    // Display the profile of the user who sent the request
                    // You would need to fetch the user details from the `users` collection
                    
                    if let imageUrl = URL(string: request.profileImage), request.profileImage != "" {
                       WebImage(url: imageUrl)
                           .resizable()
                           .scaledToFit()
                           .frame(width: 50, height: 50)
                           .clipShape(Circle())
                   } else {
                       Image(systemName: "person.circle")
                           .resizable()
                           .scaledToFit()
                           .frame(width: 50, height: 50)
                           .clipShape(Circle())
                           .foregroundColor(.gray)
                   }

                   VStack(alignment: .leading) {
                       Text(request.displayName)
                           .font(.headline)
                   }
                    
                    Spacer()
                    // Accept Button
                   Button(action: {
                       viewModel.updateRequestStatus(requestId: request.id, newStatus: "accepted", fromUserId: request.from)
                   }) {
                       Text("Accept")
                           .frame(minWidth: 0, maxWidth: .infinity)
                           .padding(.horizontal)
                           .background(Color.green)
                           .foregroundColor(.white)
                           .cornerRadius(5)
                   }
                   .buttonStyle(PlainButtonStyle())

                   // Reject Button
                   Button(action: {
                       viewModel.updateRequestStatus(requestId: request.id, newStatus: "declined", fromUserId: request.from)
                   }) {
                       Image(systemName: "xmark")
                           .frame(minWidth: 0, maxWidth: .infinity)
                           .padding(.horizontal)
                           .background(Color.red)
                           .foregroundColor(.white)
                           .cornerRadius(5)
                   }
                   .buttonStyle(PlainButtonStyle())
               }

                }
            }
            .navigationTitle("Friend Requests")
            .onAppear {
                viewModel.fetchIncomingRequests()
            }
            .environmentObject(userSession)
        }
    }


