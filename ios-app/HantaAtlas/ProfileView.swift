import SwiftUI
import UIKit
import PhotosUI

/// Profile and settings surface for the signed-in user. Shows the account
/// identity (name / email captured at Sign in with Apple or email sign-in),
/// the on-device stats (saved countries, seen signals, muted countries),
/// the legal links, and Sign out.
struct ProfileView: View {
    let preferences: LocalPreferences

    @Environment(\.dismiss) private var dismiss

    /// Drives the identity card + Sign out. Re-renders when the session
    /// changes (e.g. /v1/auth/me enriches the cached name/email).
    @State private var session = UserSession.shared

    /// Backs the avatar PhotosPicker — Apple gives apps no access to the Apple
    /// ID photo, so the user picks their own profile picture here.
    @State private var avatarStore = ProfileAvatarStore.shared
    @State private var avatarPickerItem: PhotosPickerItem?

    /// Drives the irreversible "Delete account" flow (App Review 5.1.1(v)).
    @State private var showDeleteConfirm: Bool = false
    @State private var isDeleting: Bool = false
    @State private var showDeleteError: Bool = false

    #if DEBUG
    @State private var showNotificationTester: Bool = false
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        identityCard
                        statsCard
                        localModeCard
                        legalCard
                        accountCard
                        #if DEBUG
                        debugCard
                        #endif
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete account?", isPresented: $showDeleteConfirm) {
                Button("Delete account", role: .destructive) {
                    Task {
                        isDeleting = true
                        let ok = await session.deleteAccount()
                        isDeleting = false
                        if ok { dismiss() } else { showDeleteError = true }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your HantaAtlas account and removes your saved countries and settings from our servers. This can’t be undone.")
            }
            .alert("Couldn’t delete account", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("We couldn’t reach the server. Check your connection and try again.")
            }
            #if DEBUG
            .sheet(isPresented: $showNotificationTester) {
                NotificationTesterSheet(preferences: preferences)
            }
            #endif
        }
    }

    private var identityCard: some View {
        HStack(spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(session.currentUser?.displayNameOrFallback ?? "Signed in")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.graphite)
                    .lineLimit(1)
                Text(identitySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Signed in as \(session.currentUser?.displayNameOrFallback ?? "your account"). \(identitySubtitle).")
    }

    /// Email when we have it, otherwise the sign-in method, otherwise the
    /// current disease mode — never an empty line.
    private var identitySubtitle: String {
        if let email = session.currentUser?.email, !email.isEmpty { return email }
        if session.currentUser?.appleSubject != nil { return "Signed in with Apple" }
        return "\(preferences.selectedDiseaseMode.title) mode"
    }

    /// Tappable avatar → PhotosPicker. The user's chosen photo (or the initials
    /// monogram fallback) renders via `AccountAvatarView`; a small pencil badge
    /// signals it's editable, and a long-press offers "Remove photo".
    private var avatar: some View {
        PhotosPicker(selection: $avatarPickerItem, matching: .images, photoLibrary: .shared()) {
            AccountAvatarView(size: 64)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.terracotta)
                        .background(Circle().fill(Theme.paper))
                        .offset(x: 2, y: 2)
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if avatarStore.image != nil {
                Button(role: .destructive) { avatarStore.clear() } label: {
                    Label("Remove photo", systemImage: "trash")
                }
            }
        }
        .onChange(of: avatarPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    avatarStore.setImage(data: data)
                }
                avatarPickerItem = nil
            }
        }
        .accessibilityLabel("Profile photo. Double-tap to choose a photo.")
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statColumn(label: "Following", value: preferences.trackAllCountries ? "All" : "\(preferences.savedCountryCodes.count)", tint: Theme.terracotta)
            verticalDivider
            statColumn(label: "Seen", value: "\(preferences.seenSignalIDs.count)", tint: Theme.olive)
            verticalDivider
            statColumn(label: "Muted", value: "\(preferences.currentlyMutedCountries().count)", tint: Theme.softGrey)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
    }

    private var localModeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "iphone")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.olive)
                    .frame(width: 44, height: 44)
                    .background(Theme.bone, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Saved on this device")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.graphite)
                    Text("Your selected disease mode, saved countries, and reading state stay on this device, tied to your profile. Optional alerts can notify you when new signals match.")
                        .font(.caption)
                        .foregroundStyle(Theme.graphiteSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            DiseaseModeSwitcher(preferences: preferences)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
    }

    private var rowDivider: some View {
        Divider().overlay(Theme.stroke).padding(.leading, 60)
    }

    private var legalCard: some View {
        VStack(spacing: 0) {
            linkRow(symbol: "shield.fill", label: "Privacy Policy", urlString: "https://thehantaapp.com/privacy")
            Divider().overlay(Theme.stroke).padding(.leading, 60)
            linkRow(symbol: "doc.text.fill", label: "Terms of Service", urlString: "https://thehantaapp.com/tos")
            Divider().overlay(Theme.stroke).padding(.leading, 60)
            linkRow(symbol: "questionmark.circle.fill", label: "Support", urlString: "https://thehantaapp.com/support")
        }
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
    }

    /// Sign out. Clears the Keychain session; the root gate
    /// (HantaAtlasApp.hostContent) reactively swaps back to WelcomeView, so we
    /// dismiss the profile sheet to reveal it.
    private var accountCard: some View {
        VStack(spacing: 0) {
            actionRow(symbol: "rectangle.portrait.and.arrow.right", label: "Sign out", tileColor: Theme.terracotta, labelTint: Theme.terracotta) {
                session.signOut()
                dismiss()
            }
            rowDivider
            // Permanent account deletion — App Review 5.1.1(v) requires this
            // in-app. The destructive alert confirms before anything happens.
            actionRow(symbol: "trash", label: isDeleting ? "Deleting…" : "Delete account", tileColor: Theme.terracotta, labelTint: Theme.terracotta) {
                guard !isDeleting else { return }
                showDeleteConfirm = true
            }
        }
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
    }

    #if DEBUG
    private var debugCard: some View {
        VStack(spacing: 0) {
            actionRow(symbol: "bell.badge.waveform.fill", label: "Notification tester", tileColor: Theme.olive, labelTint: Theme.graphite) {
                showNotificationTester = true
            }
        }
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
    }
    #endif

    private func statColumn(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.heavy))
                .tracking(1.0)
                .foregroundStyle(Theme.graphiteSecondary)
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verticalDivider: some View {
        Rectangle().fill(Theme.stroke).frame(width: 1, height: 30)
    }

    private func linkRow(symbol: String, label: String, urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 14) {
                tile(symbol: symbol, color: Theme.olive)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.graphite)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func actionRow(symbol: String, label: String, tileColor: Color, labelTint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                tile(symbol: symbol, color: tileColor)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(labelTint)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.graphiteSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tile(symbol: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color)
                .frame(width: 30, height: 30)
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    ProfileView(preferences: LocalPreferences())
}
