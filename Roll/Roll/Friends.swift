//
//  Friends.swift
//  Roll
//
//  Created by Zane Sabbagh on 11/20/23.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import SDWebImageSwiftUI // To load images from URLs


struct FriendProfile: Identifiable {
    var id: String
    var displayName: String
    var profileImage: String
}

class FriendsListViewModel: ObservableObject {
    @Published var friendsList: [FriendProfile] = []
    
    @EnvironmentObject var userSession: UserSession // Use the EnvironmentObject
    private var db = Firestore.firestore()
    
    // Computed property to safely access currentUserId from userSession
    private var currentUserId: String? {
        userSession.documentID
    }

    private var listener: ListenerRegistration?
    
    deinit {
        // Remove the Firestore listener when the view model is deallocated
        listener?.remove()
    }

    func fetchFriendsProfiles() {
        guard let currentUserId = currentUserId else {
            print("Error: currentUserId is nil")
            return
        }
        // Check if the friendsList is empty before fetching data
        if friendsList.isEmpty {
            let currentUserRef = db.collection("users").document(currentUserId)
            
            listener = currentUserRef.addSnapshotListener { [weak self] documentSnapshot, error in
                if let document = documentSnapshot, let userData = document.data(), let friendsIds = userData["friends"] as? [String] {
                    self?.getFriendsDetails(friendsIds: friendsIds)
                } else {
                    print("Error fetching friends IDs: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }

    private func getFriendsDetails(friendsIds: [String]) {
        let usersRef = db.collection("users")
        
        friendsList.removeAll() // Clear the existing data
        
        for friendId in friendsIds {
            usersRef.document(friendId).getDocument { [weak self] documentSnapshot, error in
                if let document = documentSnapshot, let friendData = document.data() {
                    let friendProfile = FriendProfile(
                        id: friendId,
                        displayName: friendData["displayName"] as? String ?? "Unknown",
                        profileImage: friendData["profileImage"] as? String ?? ""
                    )
                    DispatchQueue.main.async {
                        self?.friendsList.append(friendProfile)
                    }
                } else {
                    print("Error fetching friend's details: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
}


struct FriendsListView: View {
    @ObservedObject private var viewModel = FriendsListViewModel()
    @State private var showAlert = false
    @State private var selectedFriendId: String = "" // Initialize with an empty string

    var body: some View {
        NavigationView {
            List(viewModel.friendsList, id: \.id) { friend in // Explicitly specify the ID
                HStack {
                    // Existing Image and Text view for friend
                    if let imageUrl = URL(string: friend.profileImage), friend.profileImage != "" {
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
                         Text(friend.displayName)
                    
                    Spacer()
                    
                    // Three dots button
                    Button(action: {
                        self.selectedFriendId = friend.id
                        self.showAlert = true
                    }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.gray)
                    }
                    .contextMenu {
                        Button("Block") {
                            viewModel.blockUser(friendId: friend.id)
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                }
                // Alert should be attached to the button, not the HStack
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Manage Friend"),
                        message: Text("Would you like to unfriend user?"),
                        primaryButton: .destructive(Text("Unfriend")) {
                            viewModel.unfriendUser(friendId: self.selectedFriendId)
                        },
                        secondaryButton: .destructive(Text("Cancel")) {
                        }
                    )
                }
            }
            .navigationTitle("Friends")
            .onAppear {
                viewModel.fetchFriendsProfiles()
            }
        }
    }
}


extension FriendsListViewModel {
    // Function to unfriend a user
    func unfriendUser(friendId: String) {
        guard let currentUserId = currentUserId else {
            print("Error: currentUserId is nil")
            return
        }
        // Reference to the current user's document
        let currentUserRef = db.collection("users").document(currentUserId)
        // Reference to the friend's document
        let friendRef = db.collection("users").document(friendId)
        
        // Transaction to perform the unfriending operation
        db.runTransaction { [self] (transaction, errorPointer) -> Any? in
            let currentUserDocument: DocumentSnapshot
            let friendDocument: DocumentSnapshot
            do {
                // Try to read the current user's and friend's documents
                currentUserDocument = try transaction.getDocument(currentUserRef)
                friendDocument = try transaction.getDocument(friendRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // Get current user's friends list and remove the friend ID
            if var currentUserFriends = currentUserDocument.data()?["friends"] as? [String],
               let index = currentUserFriends.firstIndex(of: friendId) {
                currentUserFriends.remove(at: index)
                transaction.updateData(["friends": currentUserFriends], forDocument: currentUserRef)
            }
            
            // Get friend's friends list and remove the current user's ID
            if var friendFriends = friendDocument.data()?["friends"] as? [String],
               let index = friendFriends.firstIndex(of: currentUserId) {
                friendFriends.remove(at: index)
                transaction.updateData(["friends": friendFriends], forDocument: friendRef)
            }
            
            return nil
        } completion: { [weak self] _, error in
            if let error = error {
                print("Unfriend transaction failed: \(error)")
            } else {
                DispatchQueue.main.async {
                    // Remove the friend from the friendsList array
                    self?.friendsList.removeAll { $0.id == friendId }
                }
            }
        }
    }
    
    // Function to block a user
    func blockUser(friendId: String) {
        // Reference to the friend's document
        guard let currentUserId = currentUserId else {
            print("Error: currentUserId is nil")
            return
        }
        let friendRef = db.collection("users").document(friendId)
        
        // Transaction to perform the blocking operation
        db.runTransaction { [self] (transaction, errorPointer) -> Any? in
            let friendDocument: DocumentSnapshot
            do {
                // Try to read the friend's document
                friendDocument = try transaction.getDocument(friendRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // Get the current friend's blockedBy list and add the currentUserId
            if var blockedByList = friendDocument.data()?["blockedBy"] as? [String] {
                blockedByList.append(currentUserId)
                transaction.updateData(["blockedBy": blockedByList], forDocument: friendRef)
            } else {
                // If the blockedBy list doesn't exist, create it with the currentUserId
                transaction.updateData(["blockedBy": [currentUserId]], forDocument: friendRef)
            }
            
            return nil
        } completion: { [weak self] _, error in
            if let error = error {
                print("Block transaction failed: \(error)")
            } else {
                DispatchQueue.main.async {
                    // Remove the friend from the friendsList array
                    self?.friendsList.removeAll { $0.id == friendId }
                }
            }
        }
    }
}
