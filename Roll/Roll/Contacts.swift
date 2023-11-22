//
//  Contacts.swift
//  jeraldjournal
//
//  Created by Zane Sabbagh on 11/16/23.
//

import Foundation
import SwiftUI
import Contacts
import FirebaseFirestore

struct ContactInfo: Identifiable {
    let id: String
    let givenName: String
    let familyName: String
    let imageData: Data?
    let phoneNumber: String?
    var isSelected: Bool = false
    
    
    // Computed property to return the full name
    var fullName: String {
        "\(givenName) \(familyName)"
    }
    
    // Check if the contact has an image
    var hasImage: Bool {
        imageData != nil
    }
    
    init(contact: CNContact) {
        self.id = contact.identifier
        self.givenName = contact.givenName
        self.familyName = contact.familyName
        self.imageData = contact.thumbnailImageData
        self.phoneNumber = contact.phoneNumbers.first?.value.stringValue
    }
}

class ContactsViewModel: ObservableObject {
    @Published var contacts: [ContactInfo] = []
    @Published var searchText = ""

    private var db = Firestore.firestore()
    private let store = CNContactStore()
    var selectedContactsCount: Int {
            contacts.filter { $0.isSelected }.count
        }
    
    func uploadSelectedContact() {
        // Filter out the selected contacts and create a dictionary of their IDs and phone numbers
        let selectedContactInfo = contacts.filter { $0.isSelected && $0.phoneNumber != nil }
              .reduce(into: [String: String]()) { dict, contact in
                  dict[contact.id] = contact.phoneNumber
              }
        
        // Reference to the document for the specific user
        let userDocument = db.collection("users").document("100100")
        
        // Update the z-contacts map with the contact ID: Phone number pairs
        userDocument.setData(["z-contacts": selectedContactInfo], merge: true) { error in
            if let error = error {
                print("Error updating contact info: \(error.localizedDescription)")
            } else {
                print("Contact info updated successfully")
            }
        }
    }


    func requestAccess() {
        store.requestAccess(for: .contacts) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    self.fetchContacts()
                }
            } else {
                // Handle the error or denial of access appropriately.
            }
        }
    }
    
    func toggleContactSelected(_ contactId: String) {
        if let index = contacts.firstIndex(where: { $0.id == contactId }) {
            contacts[index].isSelected.toggle()
            uploadSelectedContact()
        }
    }

    private func fetchContacts() {
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactThumbnailImageDataKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        do {
            try store.enumerateContacts(with: request) { [weak self] contact, stop in
                if !contact.phoneNumbers.isEmpty { // Check if the contact has a phone number
                    let contactInfo = ContactInfo(contact: contact)
                    self?.contacts.append(contactInfo)
                }
            }
            // After all contacts are fetched, sort them as required
            sortContacts()
        } catch {
            // Handle the error appropriately.
        }
    }

    private func sortContacts() {
        contacts.sort {
            if $0.hasImage == $1.hasImage {
                return $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
            }
            return $0.hasImage && !$1.hasImage
        }
    }

    var filteredContacts: [ContactInfo] {
        // Filter out contacts without a phone number
        let contactsWithPhoneNumbers = contacts.filter { $0.phoneNumber != nil }
        
        // Apply search filter if needed
        let filtered = searchText.isEmpty ? contactsWithPhoneNumbers : contactsWithPhoneNumbers.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText)
        }
        
        // Sort the filtered contacts
        return filtered.sorted {
            if $0.hasImage == $1.hasImage {
                return $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
            }
            return $0.hasImage && !$1.hasImage
        }
    }
    
    

}

struct ContactsView: View {
    @StateObject private var viewModel = ContactsViewModel()
    @State private var navigateToHome = false
    
    private func colorForSelection(fraction: CGFloat) -> Color {
        // Define the start and end colors as faint light green to darker green
        let startColor = UIColor(red: 0.7, green: 1.0, blue: 0.7, alpha: 1.0) // faint light green
        let endColor = UIColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0) // darker green

        let startComponents = startColor.cgColor.components ?? [0.7, 1.0, 0.7, 1.0]
        let endComponents = endColor.cgColor.components ?? [0.0, 0.5, 0.0, 1.0]

        let red = startComponents[0] + fraction * (endComponents[0] - startComponents[0])
        let green = startComponents[1] + fraction * (endComponents[1] - startComponents[1])
        let blue = startComponents[2] + fraction * (endComponents[2] - startComponents[2])
        let alpha = startComponents[3] + fraction * (endComponents[3] - startComponents[3])

        return Color(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
    }

    var body: some View {
        NavigationView {
            VStack {
                List(viewModel.filteredContacts) { contact in
                    HStack {
                        Button(action: {
                            viewModel.toggleContactSelected(contact.id)
                        }) {
                            if contact.isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .frame(width: 40, height: 40)
                            } else if let imageData = contact.imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                            }
                        }
                        VStack(alignment: .leading) {
                            Text(contact.fullName)
                                .fontWeight(.medium)
                            // Add more contact details here if needed
                        }
                    }
                    .padding(.vertical, 8)
                }
                .navigationBarTitle("Tap your besties")
                .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
                
                
                // Invisible NavigationLink that will activate when navigateToHome is true
                NavigationLink(destination: Home(), isActive: $navigateToHome) {
                    EmptyView()
                }
                .hidden() // Hide the NavigationLink
                Button(action: {
                    if viewModel.selectedContactsCount >= 10 {
                        navigateToHome = true // This will trigger the navigation
                    }
                }) {
                    Text(viewModel.selectedContactsCount == 10 ? "Continue" : "\(viewModel.selectedContactsCount)/10")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colorForSelection(fraction: CGFloat(viewModel.selectedContactsCount) / 10))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .padding(.horizontal, UIScreen.main.bounds.width * 0.05)
                }
                .disabled(viewModel.selectedContactsCount < 10) // The button is disabled if less than 10 contacts are selected
            }
            .onAppear {
                viewModel.requestAccess()
            }
        }
    }
}




// Define the root view
struct Contacts: View {
    var body: some View {
        ContactsView()
    }
}



//
//  Friends.swift
//  Roll
//
//  Created by Zane Sabbagh on 11/20/23.
//

//import Foundation
//import SwiftUI
//import Firebase
//
//
//struct User: Identifiable, Decodable {
//    let id: String
//    let displayName: String
//    // Add other properties as needed
//}
//
//class UsersViewModel: ObservableObject {
//    @Published var users: [User] = []
//    @Published var searchText = ""
//    
//    private var db = Firestore.firestore()
//    
//    func fetchUsers() {
//        db.collection("users").addSnapshotListener { (querySnapshot, error) in
//            guard let documents = querySnapshot?.documents else {
//                print("No documents")
//                return
//            }
//            
//            self.users = documents.compactMap { queryDocumentSnapshot -> User? in
//                return try? queryDocumentSnapshot.data(as: User.self)
//            }
//        }
//    }
//    
//    var filteredUsers: [User] {
//        if searchText.isEmpty {
//            return users
//        } else {
//            return users.filter { $0.displayName.lowercased().contains(searchText.lowercased()) }
//        }
//    }
//}
//
//struct FriendsView: View {
//    @ObservedObject private var viewModel = UsersViewModel()
//    
//    var body: some View {
//        NavigationView {
//            VStack {
//                SearchBar(text: $viewModel.searchText)
//                List(viewModel.filteredUsers) { user in
//                    HStack {
//                        Text(user.displayName)
//                        Spacer()
//                        // Add more user details here as needed
//                    }
//                }
//            }
//            .navigationTitle("Friends")
//            .onAppear {
//                viewModel.fetchUsers()
//            }
//        }
//    }
//}
//
//struct SearchBar: UIViewRepresentable {
//    @Binding var text: String
//
//    class Coordinator: NSObject, UISearchBarDelegate {
//        @Binding var text: String
//
//        init(text: Binding<String>) {
//            _text = text
//        }
//
//        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
//            text = searchText
//        }
//    }
//
//    func makeCoordinator() -> Coordinator {
//        return Coordinator(text: $text)
//    }
//
//    func makeUIView(context: Context) -> UISearchBar {
//        let searchBar = UISearchBar(frame: .zero)
//        searchBar.delegate = context.coordinator
//        return searchBar
//    }
//
//    func updateUIView(_ uiView: UISearchBar, context: Context) {
//        uiView.text = text
//    }
//}
//
//// Extend QueryDocumentSnapshot to be able to decode directly
//extension QueryDocumentSnapshot {
//    func data<T: Decodable>(as objectType: T.Type) throws -> T? {
//        let jsonData = try JSONSerialization.data(withJSONObject: data(), options: [])
//        let object = try JSONDecoder().decode(T.self, from: jsonData)
//        return object
//    }
//}

