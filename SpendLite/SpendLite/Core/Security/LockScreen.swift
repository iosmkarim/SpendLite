//
//  LockScreen.swift
//  SpendLite
//

import SwiftUI

/// Covers the app while it's locked. Asks for Face ID as soon as it appears;
/// the button lets the user try again (e.g. after cancelling).
struct LockScreen: View {
    @ObservedObject var appLock: AppLock

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.brand)
                .iconTile(.brand, size: 84, cornerRadius: 24)
            VStack(spacing: 6) {
                Text("SpendLite is locked")
                    .font(.title2.bold())
                Text("Unlock to see your spending.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await appLock.unlock() }
            } label: {
                Label("Unlock with \(appLock.methodName)", systemImage: appLock.authenticator.systemImage)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(appLock.isAuthenticating)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            .accessibilityIdentifier("lock.unlock")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
        .task { await appLock.unlock() }
        // A container element, so its id doesn't override the button's own id.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lock.screen")
    }
}

/// Shown in the app switcher while locked-mode is on, so amounts aren't visible in the snapshot.
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.brand)
                .iconTile(.brand, size: 84, cornerRadius: 24)
        }
    }
}

/// Watches the lock and shows the lock screen (or the app-switcher cover) above the app.
struct AppLockGate: View {
    @ObservedObject var appLock: AppLock
    let scenePhase: ScenePhase

    var body: some View {
        ZStack {
            if appLock.isLocked {
                LockScreen(appLock: appLock)
                    .transition(.opacity)
            } else if appLock.isEnabled && scenePhase == .background {
                PrivacyCover()
            }
        }
        .animation(.easeOut(duration: 0.2), value: appLock.isLocked)
    }
}
