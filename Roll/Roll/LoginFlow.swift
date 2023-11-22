import SwiftUI
import FirebaseAuth
import SwiftUIIntrospect
import FirebaseFirestore

struct Login: View {
    @Binding var isUserLoggedIn: Bool
    @State private var stage: LoginStage = .enterPhoneNumber
    @State private var verificationID: String? = nil // To store the verification ID
    @State private var phoneNumber: String = "+1" // Define phoneNumber here

    enum LoginStage {
        case enterPhoneNumber
        case enterVerificationCode
    }

    var body: some View {
        VStack {
            if stage == .enterPhoneNumber {
                PhoneNumberView(stage: $stage, verificationID: $verificationID, phoneNumber: $phoneNumber)
                    .onAppear {
                        DispatchQueue.main.async {
                            stage = .enterPhoneNumber
                        }
                    }
            } else if stage == .enterVerificationCode {
                VerificationCodeView(stage: $stage, isUserLoggedIn: $isUserLoggedIn, verificationID: $verificationID, phoneNumber: $phoneNumber)
                    .onAppear {
                        DispatchQueue.main.async {
                            stage = .enterVerificationCode
                        }
                    }
            }
        }
    }
}

struct PhoneNumberView: View {
    @Binding var stage: Login.LoginStage
    @Binding var verificationID: String? // To store the verification ID
    @Binding var phoneNumber: String


    var body: some View {
        VStack {
            Text("Enter your 📞")
                .font(.title)
                .padding()

            TextField("Phone Number", text: $phoneNumber)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .padding()
                .textContentType(.telephoneNumber) // Suggest phone numbers
                .introspect(.textField, on: .iOS(.v13, .v14, .v15, .v16, .v17)) { textField in
                       textField.becomeFirstResponder()

                }

            Button(action: {
                let fullPhoneNumber = phoneNumber // Already includes the +1
                PhoneAuthProvider.provider().verifyPhoneNumber(fullPhoneNumber, uiDelegate: nil) { (verificationID, error) in
                    if let error = error {
                        // Handle the error here
                        print(error.localizedDescription)
                        return
                    }
                    // Store the verificationID and move to the next stage
                    self.verificationID = verificationID
                    stage = .enterVerificationCode
                }
            }) {
                Text("Next")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

struct VerificationCodeView: View {
    @Binding var stage: Login.LoginStage
    @Binding var isUserLoggedIn: Bool
    @Binding var verificationID: String? // Use this for code verification
    @State private var verificationCode = ""
    @State private var userDocumentID: String?
    @Binding var phoneNumber: String
    @EnvironmentObject var userSession: UserSession
    
    var body: some View {
        VStack {
            Text("Incoming code ✈️")
                .font(.title)
                .padding()
            
            TextField("Verification Code", text: $verificationCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode) // Suggest one-time codes
                .padding()
                .introspect(.textField, on: .iOS(.v13, .v14, .v15, .v16, .v17)) { textField in
                    textField.becomeFirstResponder()
                }
                    
            Button(action: handleLogin) {
                Text("Log In")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
    
    private func handleLogin() {
        guard let verificationID = verificationID else {
            // Handle error: verificationID was nil
            return
        }
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        
        Auth.auth().signIn(with: credential) { [self] (authResult, error) in
            if let error = error {
                // Handle the error here
                print(error.localizedDescription)
                return
            }
            // User is signed in, now add a document to Firestore
            self.addUserToFirestore(phoneNumber: phoneNumber)
        }
    }
    
    private func addUserToFirestore(phoneNumber: String) {
        let db = Firestore.firestore()
        var ref: DocumentReference? = nil
        ref = db.collection("users").addDocument(data: [
            "displayName": "Zane Sabbagh",
            "phoneNumber": phoneNumber // Include the phone number
        ]) { [self] err in
            if let err = err {
                print("Error adding document: \(err)")
            } else {
                guard let documentID = ref?.documentID else { return }
                self.userDocumentID = documentID
                self.userSession.documentID = documentID
                print("Document added with ID: \(documentID)")
                self.isUserLoggedIn = true
            }
        }
    }
}
