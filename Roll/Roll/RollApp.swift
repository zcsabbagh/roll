import SwiftUI
import FirebaseCore
import FirebaseAuth
import Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        // Register for remote notifications
        application.registerForRemoteNotifications()
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if DEBUG
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
        #else
        Auth.auth().setAPNSToken(deviceToken, type: .prod)
        #endif
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Handle failure to register for remote notifications
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification notification: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }
        // Handle other notifications.
    }
}

@main
struct YourApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var isUserLoggedIn = false // Variable to track user authentication
    var userSession = UserSession()
   
    var body: some Scene {
        
        WindowGroup {
            
            //            Home()
            if isUserLoggedIn {
                // If the user is logged in, show the TabView
                TabView {
                    NavigationView {
                        Profile()
                            .environmentObject(userSession)
                    }
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
                    
                    NavigationView {
                        Feed()
                            .environmentObject(userSession)
                    }
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Feed")
                    }
                    
                    NavigationView {
                        Friends()
                            .environmentObject(userSession)
                    }
                    .tabItem {
                        Image(systemName: "person.2.fill")
                        Text("Friends")
                    }
                }   
            } else {
                LoginFlow(isUserLoggedIn: $isUserLoggedIn)
                    .environmentObject(userSession)
            }
        }
    }
    
    // Define your Friends, Feed, and Profile views
    
    struct Friends: View {
        var body: some View {
            TabView {
                FriendsListView()
                    .tabItem {
                        Image(systemName: "person.3.fill")
                        Text("Friends")
                    }

                UsersListView()
                    .tabItem {
                        Image(systemName: "person")
                        Text("Users")
                    }

                FriendRequestsView()
                    .tabItem {
                        Image(systemName: "envelope")
                        Text("Requests")
                    }
            }
        }
    }
    
    struct Feed: View {
        var body: some View {
            let feedViewModel = FeedViewModel()
            FeedView(viewModel: feedViewModel)
            // Your Feed view code goes here
        }
    }
    
    struct Profile: View {
        var body: some View {
            let feedViewModel = FeedViewModel()
            FeedView(viewModel: feedViewModel)
        }
    }
    
    // Create a LoginFlow view to handle authentication and login
    struct LoginFlow: View {
        @Binding var isUserLoggedIn: Bool
        
        var body: some View {
            NavigationView {
                Login(isUserLoggedIn: $isUserLoggedIn)
            }
        }
    }
}


class UserSession: ObservableObject {
    @Published var documentID: String?
    // Add any other session-related properties here
}
