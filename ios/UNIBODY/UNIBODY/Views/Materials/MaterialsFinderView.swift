import SwiftUI
import PDFKit

private enum FinderSubfolder: String, Identifiable {
    case homework = "homework"
    case slides = "slides"
    var id: String { rawValue }
}

private struct ActivePDFPreviewItem: Identifiable {
    let id = UUID()
    let title: String
    let filename: String
    let fileURL: URL
    let portalURL: String
}

public struct MaterialsFinderView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var materialsService = CourseMaterialsService.shared

    @State private var selectedCourseId: String? = nil
    @State private var selectedSubfolder: FinderSubfolder? = nil
    @State private var searchQuery: String = ""
    @State private var isLoadingPDF: String? = nil
    @State private var activePDFItem: ActivePDFPreviewItem? = nil

    public init() {}

    private var selectedCourse: MaterialCourse? {
        guard let cid = selectedCourseId else { return nil }
        return materialsService.courses.first(where: { $0.courseId == cid })
    }

    private var totalPendingCount: Int {
        materialsService.courses.reduce(0) { $0 + $1.pendingCount }
    }

    private var totalCompletedCount: Int {
        materialsService.courses.reduce(0) { $0 + $1.completedCount }
    }

    private var totalSlidesCount: Int {
        materialsService.courses.reduce(0) { $0 + $1.lectureSlides.count }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AeroBackgroundView()

                VStack(spacing: 0) {
                    // macOS / iOS Finder Window Top Bar (Traffic Lights + Breadcrumb Path + Search)
                    finderTopBar

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                searchResultsView
                            } else if let course = selectedCourse {
                                if let sub = selectedSubfolder {
                                    switch sub {
                                    case .homework:
                                        homeworkFolderContentsView(course: course)
                                    case .slides:
                                        slidesFolderContentsView(course: course)
                                    }
                                } else {
                                    // STRICT 2-FOLDER VIEW (No cluttered 3rd section!)
                                    courseTwoFoldersView(course: course)
                                }
                            } else {
                                rootFinderCoursesView
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await materialsService.syncAllCourses(
                            username: appState.username,
                            password: appState.password
                        )
                    }

                    // Finder Status Footer Bar
                    finderStatusBar
                }
            }
            .navigationTitle("Materialien")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 6) {
                        if selectedCourseId != nil {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if selectedSubfolder != nil {
                                        selectedSubfolder = nil
                                    } else {
                                        selectedCourseId = nil
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.subheadline.weight(.bold))
                                    Text("Zurück")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundColor(AeroTheme.skyBlue)
                            }
                        } else {
                            Text("BETA")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AeroTheme.solarOrange.opacity(0.22)))
                                .overlay(Capsule().strokeBorder(AeroTheme.solarOrange.opacity(0.55), lineWidth: 1))
                                .foregroundColor(AeroTheme.solarOrange)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await materialsService.syncAllCourses(
                                username: appState.username,
                                password: appState.password
                            )
                        }
                    } label: {
                        if materialsService.isSyncingMoodle {
                            ProgressView()
                                .tint(AeroTheme.skyBlue)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(AeroTheme.skyBlue)
                        }
                    }
                    .accessibilityLabel("Materialien abgleichen")
                }
            }
            .sheet(item: $activePDFItem) { item in
                NativePDFPreviewSheet(item: item)
            }
            .task {
                if !appState.username.isEmpty && !appState.password.isEmpty {
                    await materialsService.syncAllMoodleCourses(
                        username: appState.username,
                        password: appState.password
                    )
                }
            }
        }
    }

    // MARK: - Finder Top Bar (Breadcrumbs & Search)

    private var finderTopBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // macOS Traffic Light Dots
                HStack(spacing: 5) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 10, height: 10)
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 10, height: 10)
                    Circle().fill(Color(red: 0.15, green: 0.78, blue: 0.25)).frame(width: 10, height: 10)
                }
                .padding(.trailing, 4)

                // Interactive Breadcrumb Trail
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedCourseId = nil
                                selectedSubfolder = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(AeroTheme.skyBlue)
                                Text("Materialien")
                                    .fontWeight(selectedCourseId == nil ? .bold : .medium)
                            }
                            .font(.caption)
                            .foregroundColor(selectedCourseId == nil ? .white : .secondary)
                        }
                        .buttonStyle(.plain)

                        if let course = selectedCourse {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedSubfolder = nil
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(AeroTheme.skyBlue)
                                    Text(course.shortTitle)
                                        .fontWeight(selectedSubfolder == nil ? .bold : .medium)
                                        .lineLimit(1)
                                }
                                .font(.caption)
                                .foregroundColor(selectedSubfolder == nil ? .primary : .secondary)
                            }
                            .buttonStyle(.plain)

                            if let sub = selectedSubfolder {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)

                                Text(sub == .homework ? course.homeworkFolderTitle : course.slidesFolderTitle)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer()
            }

            // Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Aufgaben, bl01.pdf, Übung 1 oder Folien suchen...", text: $searchQuery)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.28))
    }

    // MARK: - Level 0: Root Course Folders

    private var rootFinderCoursesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary KPI Strip
            HStack(spacing: 10) {
                FinderStatCard(
                    value: "\(totalPendingCount)",
                    label: "Offene Abgaben",
                    icon: "clock.badge.exclamationmark.fill",
                    color: AeroTheme.solarOrange
                )
                FinderStatCard(
                    value: "\(totalCompletedCount)",
                    label: "Erledigt",
                    icon: "checkmark.seal.fill",
                    color: AeroTheme.emerald
                )
                FinderStatCard(
                    value: "\(totalSlidesCount)",
                    label: "Vorlesungsfolien",
                    icon: "rectangle.stack.fill",
                    color: AeroTheme.skyBlue
                )
            }

            if let syncMsg = materialsService.lastSyncStatus {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(AeroTheme.emerald)
                    Text(syncMsg)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.primary.opacity(0.9))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(AeroTheme.emerald.opacity(0.15)))
            }

            Text("Studienmodule (\(materialsService.courses.count) Ordner · Inoffizielles Tool)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            LazyVStack(spacing: 12) {
                ForEach(materialsService.courses) { course in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            selectedCourseId = course.courseId
                            selectedSubfolder = nil
                        }
                    } label: {
                        FinderCourseFolderRow(course: course)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Level 1: Strictly 2 Folders per Course (Homework & Lecture Slides)

    private func courseTwoFoldersView(course: MaterialCourse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Course Info Banner
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    AeroBadge(course.platformHost, icon: course.platformIcon)
                    AeroBadge("BETA", color: AeroTheme.solarOrange)
                    Spacer()
                    if let url = URL(string: course.courseUrl) {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text("Im Portal")
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.caption.weight(.bold))
                            .foregroundColor(AeroTheme.skyBlue)
                        }
                    }
                }

                Text(course.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)

                Text(course.lecturer)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frutigerGlass(cornerRadius: 16)

            Text("ORDNER (2 ELEMENTE)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            // STRICTLY 2 FOLDERS:
            // Folder 1: Hausaufgaben / Übungsblätter / Übungen
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    selectedSubfolder = .homework
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AeroTheme.skyBlue, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 54, height: 44)
                            .shadow(color: AeroTheme.skyBlue.opacity(0.35), radius: 6, x: 0, y: 3)
                        Image(systemName: "folder.fill.badge.person.crop")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.homeworkFolderTitle)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundColor(.primary)

                        HStack(spacing: 8) {
                            Text("\(course.homework.count) \(course.homework.count == 1 ? "Aufgabenblatt" : "Aufgabenblätter")")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if course.pendingCount > 0 {
                                AeroBadge("\(course.pendingCount) offen", color: AeroTheme.solarOrange)
                            } else {
                                AeroBadge("Alle erledigt", color: AeroTheme.emerald)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(AeroTheme.skyBlue)
                }
                .padding(16)
                .frutigerGlass(cornerRadius: 16)
            }
            .buttonStyle(.plain)

            // Folder 2: Vorlesungsfolien
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    selectedSubfolder = .slides
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.teal.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 54, height: 44)
                            .shadow(color: Color.cyan.opacity(0.35), radius: 6, x: 0, y: 3)
                        Image(systemName: "play.rectangle.on.rectangle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.slidesFolderTitle)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundColor(.primary)

                        Text("\(course.lectureSlides.count) Foliensätze · Keynote-Ansicht & Direkt-PDF")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(AeroTheme.skyBlue)
                }
                .padding(16)
                .frutigerGlass(cornerRadius: 16)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Level 2A: Homework & Exercise Sheets Folder

    private func homeworkFolderContentsView(course: MaterialCourse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(course.homeworkFolderTitle.uppercased()) (\(course.homework.count) ELEMENTE)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                if course.courseId == "infEWInf-01a" {
                    Text("#module-29808")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AeroTheme.skyBlue)
                }
            }
            .padding(.horizontal, 4)

            ForEach(course.homework) { hw in
                HomeworkFinderCard(
                    course: course,
                    homework: hw,
                    isDownloading: isLoadingPDF == hw.id,
                    onToggleComplete: {
                        materialsService.toggleHomeworkCompleted(courseId: course.courseId, homeworkId: hw.id)
                    },
                    onOpenPDF: {
                        Task {
                            await openPDF(
                                itemId: hw.id,
                                courseId: course.courseId,
                                filename: hw.filename,
                                title: hw.title,
                                downloadUrl: hw.downloadUrl.isEmpty ? course.courseUrl : hw.downloadUrl
                            )
                        }
                    }
                )
            }
        }
    }

    // MARK: - Level 2B: Lecture Slides Folder (Uncluttered Keynote-Style Cards)

    private func slidesFolderContentsView(course: MaterialCourse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("🏛️ VORLESUNGSFOLIEN (\(course.lectureSlides.count) FOLIENSÄTZE)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            LazyVStack(spacing: 12) {
                ForEach(course.lectureSlides) { slide in
                    KeynoteSlideCard(
                        course: course,
                        slide: slide,
                        isDownloading: isLoadingPDF == slide.id,
                        onOpenPDF: {
                            Task {
                                await openPDF(
                                    itemId: slide.id,
                                    courseId: course.courseId,
                                    filename: slide.filename,
                                    title: slide.title,
                                    downloadUrl: slide.url.isEmpty ? course.courseUrl : slide.url
                                )
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Search Results View

    private var searchResultsView: some View {
        let q = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 14) {
            Text("SUCHERGEBNISSE FÜR \"\(searchQuery.uppercased())\"")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)

            ForEach(materialsService.courses) { course in
                let matchedHw = course.homework.filter {
                    $0.title.lowercased().contains(q) ||
                    $0.filename.lowercased().contains(q) ||
                    $0.description.lowercased().contains(q)
                }
                let matchedSlides = course.lectureSlides.filter {
                    $0.title.lowercased().contains(q) ||
                    $0.filename.lowercased().contains(q)
                }

                if !matchedHw.isEmpty || !matchedSlides.isEmpty {
                    Text(course.shortTitle)
                        .font(.caption.weight(.bold))
                        .foregroundColor(AeroTheme.skyBlue)
                        .padding(.top, 4)

                    ForEach(matchedHw) { hw in
                        HomeworkFinderCard(
                            course: course,
                            homework: hw,
                            isDownloading: isLoadingPDF == hw.id,
                            onToggleComplete: {
                                materialsService.toggleHomeworkCompleted(courseId: course.courseId, homeworkId: hw.id)
                            },
                            onOpenPDF: {
                                Task {
                                    await openPDF(
                                        itemId: hw.id,
                                        courseId: course.courseId,
                                        filename: hw.filename,
                                        title: hw.title,
                                        downloadUrl: hw.downloadUrl.isEmpty ? course.courseUrl : hw.downloadUrl
                                    )
                                }
                            }
                        )
                    }

                    ForEach(matchedSlides) { slide in
                        KeynoteSlideCard(
                            course: course,
                            slide: slide,
                            isDownloading: isLoadingPDF == slide.id,
                            onOpenPDF: {
                                Task {
                                    await openPDF(
                                        itemId: slide.id,
                                        courseId: course.courseId,
                                        filename: slide.filename,
                                        title: slide.title,
                                        downloadUrl: slide.url.isEmpty ? course.courseUrl : slide.url
                                    )
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Finder Bottom Status Bar

    private var finderStatusBar: some View {
        HStack {
            HStack(spacing: 5) {
                Circle()
                    .fill(AeroTheme.emerald)
                    .frame(width: 6, height: 6)
                Text("UNIBODY Finder · Beta")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let course = selectedCourse {
                if let sub = selectedSubfolder {
                    let count = sub == .homework ? course.homework.count : course.lectureSlides.count
                    Text("\(count) Objekte · \(course.platformHost)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text("2 Ordner · \(course.totalFilesCount) PDFs")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            } else {
                Text("\(materialsService.courses.count) Module · \(totalPendingCount) offen")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.25))
    }

    // MARK: - Open PDF Action

    private func openPDF(itemId: String, courseId: String, filename: String, title: String, downloadUrl: String) async {
        isLoadingPDF = itemId
        defer { isLoadingPDF = nil }

        if let fileURL = await materialsService.resolvePDFFileURL(
            courseId: courseId,
            filename: filename,
            title: title,
            downloadUrl: downloadUrl,
            username: appState.username,
            password: appState.password
        ) {
            activePDFItem = ActivePDFPreviewItem(
                title: title,
                filename: filename,
                fileURL: fileURL,
                portalURL: downloadUrl
            )
        }
    }
}

// MARK: - Subcomponents

private struct FinderStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Spacer()
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundColor(.primary)
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frutigerGlass(cornerRadius: 14)
    }
}

private struct FinderCourseFolderRow: View {
    let course: MaterialCourse

    var body: some View {
        HStack(spacing: 14) {
            // macOS Aqua Folder Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.25, green: 0.68, blue: 1.0), Color(red: 0.05, green: 0.45, blue: 0.90)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 46)
                    .shadow(color: AeroTheme.skyBlue.opacity(0.35), radius: 5, x: 0, y: 3)

                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(course.shortTitle)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    if course.pendingCount > 0 {
                        AeroBadge("\(course.pendingCount) offen", color: AeroTheme.solarOrange)
                    } else {
                        AeroBadge("Aktuell", color: AeroTheme.emerald)
                    }
                }

                Text("\(course.lecturer) · \(course.platformHost)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Label("2 Ordner", systemImage: "folder")
                    Label("\(course.homework.count) Aufgaben", systemImage: "doc.text")
                    Label("\(course.lectureSlides.count) Folien", systemImage: "rectangle.stack")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AeroTheme.skyBlue.opacity(0.9))
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frutigerGlass(cornerRadius: 16)
    }
}

// MARK: - Homework / Exercise Sheet Card

private struct HomeworkFinderCard: View {
    let course: MaterialCourse
    let homework: HomeworkItem
    let isDownloading: Bool
    let onToggleComplete: () -> Void
    let onOpenPDF: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggleComplete) {
                    Image(systemName: homework.completed ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(homework.completed ? AeroTheme.emerald : AeroTheme.skyBlue)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        AeroBadge(
                            homework.deadlineRemainingText,
                            icon: homework.completed ? "checkmark.seal.fill" : "clock.fill",
                            color: homework.completed ? AeroTheme.emerald : (homework.isUrgent ? AeroTheme.rubyRed : AeroTheme.solarOrange)
                        )
                        if homework.pointsMax > 0 {
                            AeroBadge("\(homework.pointsMax) P.", color: AeroTheme.skyBlue)
                        }
                    }

                    Text(homework.title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundColor(homework.completed ? .secondary : .white)
                        .strikethrough(homework.completed)

                    Text("\(homework.filename) · \(homework.fileSize) · \(homework.submissionFormat)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            if !homework.description.isEmpty {
                Text(homework.description)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.85))
            }

            if !homework.subtasks.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2.weight(.bold))
                        Text("Teilaufgaben (\(homework.subtasks.count))")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(AeroTheme.skyBlue)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(homework.subtasks, id: \.self) { task in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: homework.completed ? "checkmark.square.fill" : "square.dotted")
                                    .font(.caption)
                                    .foregroundColor(homework.completed ? AeroTheme.emerald : AeroTheme.skyBlue)
                                Text(task)
                                    .font(.caption2)
                                    .foregroundColor(.primary.opacity(0.9))
                            }
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Action Buttons: Direct PDF Download/Preview + Portal Link
            HStack(spacing: 10) {
                Button(action: onOpenPDF) {
                    HStack(spacing: 6) {
                        if isDownloading {
                            ProgressView()
                                .scaleEffect(0.75)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.down.doc.fill")
                        }
                        Text(isDownloading ? "Lade PDF..." : "PDF öffnen (\(homework.filename))")
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(AeroTheme.oceanGradient))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(isDownloading)

                let targetUrlStr = homework.downloadUrl.isEmpty ? course.courseUrl : homework.downloadUrl
                if let url = URL(string: targetUrlStr) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "safari")
                            Text("LMS")
                        }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(14)
        .frutigerGlass(cornerRadius: 16)
    }
}

// MARK: - Redesigned Uncluttered Keynote-Style Lecture Slide Card

private struct KeynoteSlideCard: View {
    let course: MaterialCourse
    let slide: LectureSlideItem
    let isDownloading: Bool
    let onOpenPDF: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Keynote Presentation Thumbnail Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.08, green: 0.52, blue: 0.96), Color(red: 0.02, green: 0.28, blue: 0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                        )

                    VStack(spacing: 2) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text(slide.chapterBadge)
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(slide.title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Label("\(slide.pages) Folien", systemImage: "rectangle.stack.fill")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(AeroTheme.skyBlue)

                        Text("·")
                            .foregroundColor(.secondary)

                        Text(slide.size)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        Text("·")
                            .foregroundColor(.secondary)

                        Text(slide.date)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Text(slide.filename)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button(action: onOpenPDF) {
                    HStack(spacing: 6) {
                        if isDownloading {
                            ProgressView()
                                .scaleEffect(0.75)
                                .tint(.white)
                        } else {
                            Image(systemName: "doc.viewfinder.fill")
                        }
                        Text(isDownloading ? "Lade Folien..." : "Folien öffnen & Teilen")
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(AeroTheme.oceanGradient))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(isDownloading)

                if let url = URL(string: slide.url.isEmpty ? course.courseUrl : slide.url) {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(14)
        .frutigerGlass(cornerRadius: 16)
    }
}

// MARK: - Native PDFKit Preview & Share Sheet

private struct NativePDFPreviewSheet: View {
    @Environment(\.dismiss) var dismiss
    let item: ActivePDFPreviewItem

    var body: some View {
        NavigationStack {
            PDFKitRepresentedView(url: item.fileURL)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(item.filename)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fertig") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: item.fileURL) {
                            Label("Teilen / Sichern", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

private struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }
    }
}
