//
//  WelcomeView.swift
//  Telemetry Viewer
//
//  Created by Daniel Jilg on 04.09.20.
//

import SwiftUI
import DataTransferObjects
import TelemetryClient

struct WelcomeView: View {
    @EnvironmentObject var api: APIClient
    @State private var showLoginForm = false
    @State private var loginRequestBody = LoginRequestBody()
    @State private var isLoading = false
    @State private var showLoginErrorMessage = false
    @State private var showPasswordReset = false
    @FocusState private var emailFieldFocused: Bool

    @AppStorage("welcomeScreenCohort") var welcomeScreenCohort: String = {
        if Bool.random() {
            return "B"
        } else {
            return "A"
        }
    }()

    private var appIconName: String {
        #if os(iOS)
        return welcomeScreenCohort == "B" ? "Logo_Sticker" : "appIcon"
        #else
        return "appIcon"
        #endif
    }

    private var iconSize: CGFloat {
        showLoginForm ? 80 : 300
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            content
                .padding()
                .navigationTitle("Welcome to TelemetryDeck")
                .navigationBarTitleDisplayMode(.large)
        }
        #else
        VStack(alignment: .leading) {
            Text("Welcome to TelemetryDeck")
                .font(.title)
                .padding(.bottom)

            content
        }
        .padding()
        .frame(minHeight: 500)
        #endif
    }

    private var content: some View {
        VStack(spacing: 15) {
            #if os(macOS)
            if !showLoginForm {
                Text("TelemetryDeck is a service that helps app and web developers improve their product by " +
                     "supplying immediate, accurate telemetry data while users use your app. And the best part: " +
                     "It's all anonymized so your users' data stays private!")
                    .padding(.bottom)
                    .transition(.opacity)
            }
            #endif

            HStack {
                Spacer()
                Image(appIconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                Spacer()
            }

            if showLoginForm {
                loginFormContent
                    .transition(.opacity)
            } else {
                welcomeContent
                    .transition(.opacity)
            }

            footerContent

            Text("TelemetryDeck is currently in public beta! If things don't work the way you expect them to, please be patient, " +
                 "and share your thoughts with Daniel on GitHub or the Slack <3")
                .font(.footnote)
                .foregroundColor(.grayColor)
        }
        .sheet(isPresented: $showPasswordReset) {
            PasswordResetView()
        }
        .onAppear {
            TelemetryManager.send("WelcomeViewAppear", with: ["welcomeScreenCohort": welcomeScreenCohort])
        }
    }

    // MARK: - Welcome Content (default state)

    private var welcomeContent: some View {
        VStack(spacing: 15) {
            Button("Login to Your Account") {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showLoginForm = true
                } completion: {
                    emailFieldFocused = true
                }
                TelemetryManager.send("LoginViewAppear", with: ["welcomeScreenCohort": welcomeScreenCohort])
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal)

            Button("Register Your Account") {
                URL(string: "https://dashboard.telemetrydeck.com/registration/organization")!.open()
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.horizontal)
        }
    }

    // MARK: - Login Form Content

    private var loginFormContent: some View {
        VStack(spacing: 15) {
            if showLoginErrorMessage {
                VStack(alignment: .leading) {
                    Text("Login Failed").font(.title2)
                    Text("Something was wrong with your username or password. Please check your spelling and try again.")
                    Text("If you can't remember, use the password reset button below.").font(.footnote)
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.telemetryOrange)
                .cornerRadius(15)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack(spacing: 10) {
                #if os(macOS)
                TextField("Email", text: $loginRequestBody.userEmail)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .focused($emailFieldFocused)
                #else
                TextField("Email", text: $loginRequestBody.userEmail)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($emailFieldFocused)
                #endif

                SecureField("Password", text: $loginRequestBody.userPassword, onCommit: login)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            }
            .padding(.horizontal)

            if isLoading {
                ProgressView()
            } else {
                Button("Login", action: login)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!loginRequestBody.isValid)
                    .saturation(loginRequestBody.isValid ? 1 : 0)
                    .animation(.easeOut, value: loginRequestBody.isValid)
            }

            Button("Cancel") {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showLoginForm = false
                    showLoginErrorMessage = false
                }
            }
            .buttonStyle(SmallSecondaryButtonStyle())
            .padding(.horizontal)

            Button("Register Your Account") {
                URL(string: "https://dashboard.telemetrydeck.com/registration/organization")!.open()
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.horizontal)
        }
    }

    // MARK: - Footer (shared between states)

    private var footerContent: some View {
        AdaptiveStack(spacing: 15) {
            Button("Forgot Password?") {
                showPasswordReset = true
            }
            .buttonStyle(SmallSecondaryButtonStyle())

            Button("Docs: Getting Started →") {
                URL(string: "https://telemetrydeck.com/pages/docs.html")!.open()
            }
            .buttonStyle(SmallSecondaryButtonStyle())

            Button("Issues on GitHub →") {
                URL(string: "https://github.com/TelemetryDeck/Viewer/issues")!.open()
            }
            .buttonStyle(SmallSecondaryButtonStyle())
        }
        .padding(.horizontal)
    }

    // MARK: - Login Action

    private func login() {
        isLoading = true
        api.login(loginRequestBody: loginRequestBody) { success in
            isLoading = false
            withAnimation(.easeOut) {
                showLoginErrorMessage = !success
            }
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .environmentObject(APIClient())
    }
}
