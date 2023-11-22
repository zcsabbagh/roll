//
//  Feed.swift
//  Roll
//
//  Created by Zane Sabbagh on 11/20/23.
//






import SwiftUI
import Firebase
import FirebaseFirestore
import SDWebImageSwiftUI

struct FeedView: View {
    @ObservedObject var viewModel: FeedViewModel
    let screenHeight = UIScreen.main.bounds.height * 0.7 // 70% of the screen height
    let commentBarHeight = UIScreen.main.bounds.height * 0.1 // 10% of the screen height

    init(viewModel: FeedViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack {
                ForEach(viewModel.postsWithinLastWeek) { post in
                    VStack(spacing: 0) { // No spacing between the image and the comment box.
                        ZStack(alignment: .topLeading) {
                            if let imageURL = post.imageURL {
                                WebImage(url: imageURL)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: UIScreen.main.bounds.width * 0.975, height: screenHeight)
                                    .clipped()
                                    .cornerRadius(25)
                            } else {
                                // Render a blank image if there is no profile imageURL
                                Rectangle()
                                    .fill(Color.gray)
                                    .frame(width: UIScreen.main.bounds.width * 0.975, height: screenHeight)
                                    .clipped()
                                    .cornerRadius(25)
                            }

                            // Profile image and display name
                            HStack {
                                if let profileImageURL = post.profileImageURL {
                                    WebImage(url: profileImageURL)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        .shadow(radius: 3)
    
                                } else {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 50, height: 50)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                }

                                Text(post.displayName ?? "Unknown")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .shadow(radius: 3)
                            }
                            .padding([.top, .leading], 15)

                            // Three horizontal dots button
                            HStack {
                                Spacer()
                                Button(action: {
                                    // Action for button
                                }) {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(.white)
                                        .padding()
                                }
                            }
                            .padding(.top, 15)
                            .padding(.trailing, 15)
                        }

                        // Gray box for comments
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: UIScreen.main.bounds.width * 0.975, height: commentBarHeight)
                            .clipped()
                            .cornerRadius(25)
                            .overlay(
                                Text("Add a comment...")
                                    .foregroundColor(.white)
                                    .padding(.leading, 15),
                                alignment: .leading
                            )
                    }
                    .clipped()
                    .cornerRadius(25)
                    .padding(.bottom, 10) // Add some space between the posts
                }
            }
        }
        .onAppear {
            viewModel.fetchPostsWithinLastWeek()
        }
    }
}
class FeedViewModel: ObservableObject {
    @Published var postsWithinLastWeek: [PostModel] = []
    private var firestore = Firestore.firestore()

    func fetchPostsWithinLastWeek() {
        let currentTime = Timestamp(date: Date())
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: currentTime.dateValue())!

        firestore.collection("posts")
            .whereField("timestamp", isGreaterThan: oneWeekAgo)
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] (querySnapshot, error) in
                guard let self = self else { return }
                if let error = error {
                    print("Error fetching posts: \(error.localizedDescription)")
                    return
                }

                var posts: [PostModel] = []

                for document in querySnapshot?.documents ?? [] {
                    let data = document.data()
                    let id = document.documentID
                    if let pictureURLString = data["picture"] as? String,
                       let pictureURL = URL(string: pictureURLString),
                       let posterID = data["poster"] as? String {

                        let post = PostModel(id: id, imageURL: pictureURL, posterID: posterID)
                        posts.append(post)
                    }
                }

                self.updatePostsWithPosterDetails(posts: posts)
            }
    }

    private func updatePostsWithPosterDetails(posts: [PostModel]) {
       var updatedPosts = posts
       let group = DispatchGroup()

       for (index, post) in posts.enumerated() {
           group.enter()
           let posterID = post.posterID

           firestore.collection("users").document(posterID).getDocument { (document, error) in
               if let document = document, document.exists, error == nil {
                   let data = document.data()
                   let displayName = data?["displayName"] as? String ?? "Unknown"
                   let profileImageURL = data?["profileImage"] as? String

                   updatedPosts[index].displayName = displayName
                   updatedPosts[index].profileImageURL = profileImageURL != nil ? URL(string: profileImageURL!) : nil
               } else {
                   print("Document for poster \(posterID) does not exist")
               }
               group.leave()
           }
       }

       group.notify(queue: .main) {
           self.postsWithinLastWeek = updatedPosts
       }
   }
}

struct PostModel: Identifiable, Hashable {
    let id: String
    let imageURL: URL?
    var displayName: String? // Now optional
    var profileImageURL: URL? // Now optional
    let posterID: String // To reference the user document
}







//import Foundation
//import SwiftUI
//import FirebaseFirestore
//
//// Define your Post model based on your Firestore document structure
//struct Post: Identifiable, Codable {
//    var id: String
//    var imageURL: String
//    var posterID: String // Assuming you store the poster's ID to fetch additional details
//
//    // These fields will be fetched from the poster's document
//    var displayName: String?
//    var profileImageURL: String?
//}
//
//// ViewModel for fetching posts
//class FeedViewModel: ObservableObject {
//    @Published var posts = [Post]()
//    
//    // Firestore database reference
//    private let db = Firestore.firestore()
//
//    init() {
//        print("Entering init")
//        fetchPosts()
//    }
//
//    func fetchPosts() {
//        print("Entering fetch posts")
//        db.collection("posts").getDocuments { [weak self] (snapshot, error) in
//            if let error = error {
//                print(error.localizedDescription)
//                return
//            }
//            guard let documents = snapshot?.documents else {
//                print("No documents found")
//                return
//            }
//            self?.posts = documents.compactMap { document -> Post? in
//                var post = try? document.data(as: Post.self)
//                post?.id = document.documentID
//                return post
//            }
//            self?.fetchPostersDetails()
//        }
//    }
//
//    func fetchPostersDetails() {
//        print("Entering fetchPostersDetails")
//        let group = DispatchGroup()
//        
//        for i in 0..<posts.count {
//            group.enter()
//            let posterID = posts[i].posterID
//            db.collection("users").document(posterID).getDocument { [weak self] (document, error) in
//                if let document = document, document.exists {
//                    let data = document.data()
//                    self?.posts[i].displayName = data?["displayName"] as? String ?? "Unknown"
//                    self?.posts[i].profileImageURL = data?["profileImage"] as? String
//                } else {
//                    print("Document does not exist")
//                    self?.posts[i].displayName = "Unknown"
//                    self?.posts[i].profileImageURL = nil
//                }
//                group.leave()
//            }
//        }
//        
//        group.notify(queue: .main) {
//            self.objectWillChange.send()
//        }
//    }
//}
//
//// SwiftUI view for displaying the feed
//struct FeedView: View {
//    @ObservedObject private var viewModel = FeedViewModel()
//
//    var body: some View {
//        NavigationView {
//            ScrollView {
//                LazyVStack {
//                    ForEach(viewModel.posts) { post in
//                        VStack(alignment: .leading) {
//                            // Display the user profile picture or default image if nil
//                            AsyncImage(url: post.profileImageURL != nil ? URL(string: post.profileImageURL!) : nil) { image in
//                                image.resizable()
//                            } placeholder: {
//                                Image(systemName: "person.crop.circle.fill") // Default Apple profile image
//                            }
//                            .frame(width: 50, height: 50)
//                            .clipShape(Circle())
//
//                            // Display the username or "Unknown" if nil
//                            Text(post.displayName ?? "Unknown")
//
//                            // Display the post image
//                            AsyncImage(url: URL(string: post.imageURL)) { image in
//                                image.resizable()
//                            } placeholder: {
//                                Color.gray
//                            }
//                            .frame(maxHeight: 300)
//                            // Add other post details here
//                        }
//                    }
//                }
//            }
//            .navigationBarTitle("Feed")
//        }
//    }
//}
//
//struct FeedView_Previews: PreviewProvider {
//    static var previews: some View {
//        FeedView()
//    }
//}

