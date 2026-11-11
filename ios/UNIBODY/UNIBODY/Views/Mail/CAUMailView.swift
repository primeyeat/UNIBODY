import SwiftUI
import PDFKit

private struct MailPDFPreviewItem: Identifiable {
    let id = UUID()
    let filename: String
    let fileURL: URL
}

public struct CAUMailView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var mailService = CAUMailService.shared
    @ObservedObject private var materialsService = CourseMaterialsService.shared

    @State private var searchQuery: String = ""
    @State private var selectedMessage: CAUMailMessage? = nil
    @State private var activeAttachmentPDF: MailPDFPreviewItem? = nil

    private let folders: [(id: String, label: String, icon: String)] = [
        ("inbox", "Posteingang", "tray.full.fill"),
        ("sent", "Gesendet", "paperplane.fill"),
        ("drafts", "Entwürfe", "doc.text.fill"),
        ("trash", "Papierkorb", "trash.fill"),
        ("junk", "Spam", "exclamationmark.shield.fill")
    ]

    public init() {}

    private var visibleMessages: [CAUMailMessage] {
        mailService.messages(forFolder: mailService.selectedFolder, query: searchQuery)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AeroBackgroundView()

                VStack(spacing: 0) {
                    // Folder Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(folders, id: \.id) { folder in
                                let isSelected = mailService.selectedFolder == folder.id
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        mailService.selectedFolder = folder.id
                                    }
                                    Task {
                                        await mailService.syncEmails(folder: folder.id)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: folder.icon)
                                            .font(.caption2)
                                        Text(folder.label)
                                            .font(.caption.weight(.bold))
                                        if folder.id == "inbox" && mailService.unreadCount > 0 {
                                            Text("\(mailService.unreadCount)")
                                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color.white.opacity(0.25)))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        ZStack {
                                            if isSelected {
                                                Capsule().fill(AeroTheme.oceanGradient)
                                            } else {
                                                Capsule().fill(Color.white.opacity(0.08))
                                            }
                                        }
                                    )
                                    .foregroundColor(isSelected ? .white : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }

                    // Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("E-Mails nach Modul, Dozent oder Betreff filtern...", text: $searchQuery)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .autocorrectionDisabled()
                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityLabel("Suche leeren")
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)

                    // Mail List
                    if visibleMessages.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "envelope.open")
                                .font(.system(size: 44))
                                .foregroundColor(AeroTheme.skyBlue.opacity(0.6))
                            Text("Keine E-Mails in diesem Ordner")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Verbinde dein Studierenden-Postfach (imap.mail.uni-kiel.de:993 SSL · Inoffizieller Client) oder ziehe nach unten zum Aktualisieren.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 36)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(visibleMessages) { msg in
                                    Button {
                                        mailService.markAsRead(uid: msg.uid)
                                        selectedMessage = msg
                                    } label: {
                                        CAUMailRowCard(
                                            message: msg,
                                            onToggleRead: {
                                                mailService.toggleRead(uid: msg.uid)
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 20)
                        }
                        .refreshable {
                            await mailService.syncEmails(folder: mailService.selectedFolder)
                        }
                    }
                }
            }
            .navigationTitle("Uni-Mail (Inoffiziell)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    AeroBadge("imap.mail.uni-kiel.de", icon: "lock.shield.fill", color: AeroTheme.emerald)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await mailService.syncEmails(folder: mailService.selectedFolder)
                        }
                    } label: {
                        if mailService.isSyncing {
                            ProgressView()
                                .tint(AeroTheme.skyBlue)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(AeroTheme.skyBlue)
                        }
                    }
                    .accessibilityLabel("Postfach aktualisieren")
                }
            }
            .sheet(item: $selectedMessage) { msg in
                CAUMailDetailSheet(
                    message: msg,
                    onOpenAttachment: { att in
                        Task {
                            let courseId = msg.courseBadge ?? "infEWInf-01a"
                            if let url = await materialsService.resolvePDFFileURL(
                                courseId: courseId,
                                filename: att.filename,
                                title: att.filename,
                                downloadUrl: "",
                                username: appState.username,
                                password: appState.password
                            ) {
                                selectedMessage = nil
                                try? await Task.sleep(nanoseconds: 250_000_000)
                                activeAttachmentPDF = MailPDFPreviewItem(filename: att.filename, fileURL: url)
                            }
                        }
                    }
                )
            }
            .sheet(item: $activeAttachmentPDF) { item in
                NavigationStack {
                    MailPDFKitView(url: item.fileURL)
                        .ignoresSafeArea(edges: .bottom)
                        .navigationTitle(item.filename)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Schließen") { activeAttachmentPDF = nil }
                            }
                            ToolbarItem(placement: .primaryAction) {
                                ShareLink(item: item.fileURL) {
                                    Label("Teilen", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                }
            }
        }
    }
}

private struct CAUMailRowCard: View {
    let message: CAUMailMessage
    let onToggleRead: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(message.isUnread ? AeroTheme.skyBlue : Color.clear)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(message.senderName)
                            .font(.system(.subheadline, design: .rounded).weight(message.isUnread ? .bold : .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text(message.date)
                            .font(.caption2)
                            .foregroundColor(message.isUnread ? AeroTheme.skyBlue : .secondary)
                    }

                    if let badge = message.courseBadge {
                        AeroBadge(badge, color: AeroTheme.skyBlue)
                    }

                    Text(message.subject)
                        .font(.system(.caption, design: .rounded).weight(message.isUnread ? .bold : .medium))
                        .foregroundColor(.primary.opacity(0.95))
                        .lineLimit(2)

                    Text(message.snippet)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    if !message.attachments.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(message.attachments) { att in
                                HStack(spacing: 4) {
                                    Image(systemName: "paperclip")
                                    Text(att.filename)
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                                .foregroundColor(AeroTheme.skyBlue)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
        .padding(14)
        .frutigerGlass(cornerRadius: 16)
        .contextMenu {
            Button(action: onToggleRead) {
                Label(
                    message.isUnread ? "Als gelesen markieren" : "Als ungelesen markieren",
                    systemImage: message.isUnread ? "envelope.open.fill" : "envelope.badge.fill"
                )
            }
        }
    }
}

private struct CAUMailDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let message: CAUMailMessage
    let onOpenAttachment: (CAUMailAttachment) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AeroBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                if let badge = message.courseBadge {
                                    AeroBadge(badge, color: AeroTheme.skyBlue)
                                }
                                AeroBadge("Verifiziert · SSL", icon: "checkmark.shield.fill", color: AeroTheme.emerald)
                                Spacer()
                                Text(message.date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text(message.subject)
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundColor(.primary)

                            Divider().background(Color.white.opacity(0.15))

                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(AeroTheme.oceanGradient)
                                        .frame(width: 38, height: 38)
                                    Text(String(message.senderName.prefix(1)))
                                        .font(.headline.weight(.bold))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(message.senderName)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(.primary)
                                    Text(message.senderEmail)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .padding(16)
                        .frutigerGlass(cornerRadius: 16)

                        if !message.attachments.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ANHÄNGE (\(message.attachments.count))")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)

                                ForEach(message.attachments) { att in
                                    Button {
                                        onOpenAttachment(att)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "doc.richtext.fill")
                                                .foregroundColor(AeroTheme.skyBlue)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(att.filename)
                                                    .font(.caption.weight(.bold))
                                                    .foregroundColor(.primary)
                                                Text("\(att.size) · Direkt in UNIBODY öffnen")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.down.circle.fill")
                                                .foregroundColor(AeroTheme.skyBlue)
                                        }
                                        .padding(12)
                                        .frutigerGlass(cornerRadius: 12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Sanitized Mail Body
                        Text(message.bodyText)
                            .font(.system(.subheadline, design: .default))
                            .foregroundColor(.primary.opacity(0.92))
                            .lineSpacing(4)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frutigerGlass(cornerRadius: 16)
                    }
                    .padding()
                }
            }
            .navigationTitle("Nachricht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

private struct MailPDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.document = PDFDocument(url: url)
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
