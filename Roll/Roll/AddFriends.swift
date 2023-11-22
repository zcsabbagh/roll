//
//  AddFriends.swift
//  Roll
//
//  Created by Zane Sabbagh on 11/20/23.
//

// Note: This currently only searches through users with whom currentUser
// is not friends with. It also doesn't display currentUser in the search.
// It also doesn't display any users who have blocked the currentUser

import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import SDWebImageSwiftUI // To load images from URLs


// Step 1: Define the data model
struct UserProfile: Identifiable {
    var id: String
    var displayName: String
    var profileImage: String
    var requestSent: Bool = false
    
    init(id: String, displayName: String, profileImage: String) {
        self.id = id
        self.displayName = displayName
        self.profileImage = profileImage
    }
}


// Step 2: Create the view model
class UserProfilesViewModel: ObservableObject {
    @Published var profiles: [UserProfile] = []
    @Published var searchText = ""
    
    @EnvironmentObject var userSession: UserSession
    private var db = Firestore.firestore()
    private var currentUserId: String? {
            userSession.documentID
        }
    private var friends: [String] = [] // To store the current user's friends
    private var blocked: [String] = [] // To store the current user's blocked users

    var filteredProfiles: [UserProfile] {
        if searchText.isEmpty {
            return profiles.filter { $0.id != currentUserId && !friends.contains($0.id) && !blocked.contains($0.id) }
        } else {
            return profiles.filter { $0.displayName.lowercased().contains(searchText.lowercased()) && $0.id != currentUserId && !friends.contains($0.id) && !blocked.contains($0.id) }
        }
    }

    func fetchUserProfiles() {
        // Fetch the current user's profile to get friends and blocked lists
        guard let currentUserId = currentUserId else {
                print("Error: currentUserId is nil")
                return
            }
        db.collection("users").document(currentUserId).getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data()
                self.friends = data?["friends"] as? [String] ?? []
                self.blocked = data?["blocked"] as? [String] ?? []
                
                // Then, fetch all user profiles
                self.db.collection("users").addSnapshotListener { querySnapshot, error in
                    if let e = error {
                        print("Error fetching user profiles: \(e)")
                        return
                    }
                    
                    if let snapshotDocuments = querySnapshot?.documents {
                        self.profiles = snapshotDocuments.compactMap { doc -> UserProfile? in
                            let data = doc.data()
                            let id = doc.documentID
                            
                            if id == self.currentUserId || self.friends.contains(id) || self.blocked.contains(id) {
                                // Don't create a UserProfile for the current user or existing friends
                                return nil
                            } else if let blockedBy = data["blockedBy"] as? [String], blockedBy.contains(self.currentUserId!) {
                                // Don't create a UserProfile for users who have blocked the current user
                                return nil
                            } else {
                                let displayName = data["displayName"] as? String ?? "No Name"
                                let profileImage = data["profileImage"] as? String ?? ""
                                return UserProfile(id: id, displayName: displayName, profileImage: profileImage)
                            }
                        }
                    }
                }
            } else {
                print("Current user document does not exist or error fetching data: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    
    func sendFriendRequest(to targetUserId: String) {
        let friendRequestRef = db.collection("friendRequests").document()
        let friendRequestData: [String: Any] = [
            "to": targetUserId,
            "from": currentUserId,
            "status": "pending",
            "timestamp": Timestamp()
        ]
        
        friendRequestRef.setData(friendRequestData) { error in
            if let error = error {
                print("Error sending friend request: \(error)")
            } else {
                self.updateRequestStatus(for: targetUserId, to: true)
            }
        }
    }

    func unsendFriendRequest(to targetUserId: String) {
        // Query for the existing friend request
        db.collection("friendRequests")
            .whereField("from", isEqualTo: currentUserId)
            .whereField("to", isEqualTo: targetUserId)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error getting documents: \(error)")
                } else {
                    for document in querySnapshot!.documents {
                        document.reference.delete() { error in
                            if let error = error {
                                print("Error removing friend request: \(error)")
                            } else {
                                self.updateRequestStatus(for: targetUserId, to: false)
                            }
                        }
                    }
                }
            }
    }
    
    private func updateRequestStatus(for userId: String, to status: Bool) {
        if let index = self.profiles.firstIndex(where: { $0.id == userId }) {
            self.profiles[index].requestSent = status
        }
    }
}

// Step 3: Create the SwiftUI view
struct UsersListView: View {
    @EnvironmentObject var userSession: UserSession
    @ObservedObject private var viewModel = UserProfilesViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Search", text: $viewModel.searchText)
                    .padding(7)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal, 10)

                List(viewModel.filteredProfiles) { profile in
                    HStack {
                        WebImage(url: URL(string: profile.profileImage))
                            .resizable()
                            .placeholder(Image(systemName: "person.crop.circle"))
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                        Text(profile.displayName)
                        Spacer()
                        Button(action: {
                            if profile.requestSent {
                                viewModel.unsendFriendRequest(to: profile.id)
                            } else {
                                viewModel.sendFriendRequest(to: profile.id)
                            }
                        }) {
                            Image(systemName: profile.requestSent ? "person.badge.minus" : "person.badge.plus")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .contextMenu {
                        Button("Block") {
                            viewModel.blockUser(targetUserId: profile.id)
                        }
                        Button("Cancel") {
                        }
                        // Add more options as needed
                    }
                }
            }
            .onAppear {
                viewModel.fetchUserProfiles()
                    
            }
            .environmentObject(userSession)
        }
    }
}


extension UserProfilesViewModel {
    func blockUser(targetUserId: String) {
        guard let currentUserId = currentUserId else {
            print("Error: currentUserId is nil")
            return
        }
        guard targetUserId != currentUserId else { return } // Prevent blocking oneself
        
        let currentUserRef = db.collection("users").document(currentUserId)
        let targetUserRef = db.collection("users").document(targetUserId)
        
        // Add the user to the current user's blocked list and remove from friends if present
        currentUserRef.updateData([
            "blocked": FieldValue.arrayUnion([targetUserId]),
            "friends": FieldValue.arrayRemove([targetUserId])
        ]) { [weak self] error in
            if let error = error {
                print("Error blocking user: \(error.localizedDescription)")
            } else {
                // Update local data to reflect changes
                DispatchQueue.main.async {
                    self?.blocked.append(targetUserId)
                    self?.friends.removeAll { $0 == targetUserId }
                    self?.profiles.removeAll { $0.id == targetUserId }
                }
            }
        }
        
        // Add the current user to the target user's blockedBy list
        targetUserRef.updateData([
            "blockedBy": FieldValue.arrayUnion([currentUserId])
        ]) { error in
            if let error = error {
                print("Error updating target user's blockedBy list: \(error.localizedDescription)")
            }
        }
    }
}
