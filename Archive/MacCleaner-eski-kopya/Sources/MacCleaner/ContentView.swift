import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case junk
    case largeFiles
    case duplicates
    case trash
    case uninstaller
    case memory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Genel Bakış"
        case .junk: return "Sistem Çöpü"
        case .largeFiles: return "Büyük Dosyalar"
        case .duplicates: return "Çift Dosyalar"
        case .trash: return "Çöp Kutusu"
        case .uninstaller: return "Uygulama Kaldırıcı"
        case .memory: return "Bellek"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "gauge"
        case .junk: return "sparkles"
        case .largeFiles: return "doc.richtext"
        case .duplicates: return "doc.on.doc"
        case .trash: return "trash.slash"
        case .uninstaller: return "xmark.app"
        case .memory: return "memorychip"
        }
    }

    var tileColor: Color {
        switch self {
        case .dashboard: return Theme.dashboardColor
        case .junk: return Theme.junkColor
        case .largeFiles: return Theme.largeColor
        case .duplicates: return Theme.duplicateColor
        case .trash: return Theme.trashColor
        case .uninstaller: return Theme.uninstallColor
        case .memory: return Theme.memoryColor
        }
    }
}

struct ContentView: View {
    @State private var selection: AppSection? = .dashboard
    @State private var startQuickScan = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection)
                .frame(width: 230)
            ZStack(alignment: .topLeading) {
                AppBackground()
                switch selection {
                case .dashboard:
                    DashboardView(selection: $selection)
                case .junk:
                    SystemJunkView()
                case .largeFiles:
                    LargeFilesView()
                case .duplicates:
                    DuplicatesView()
                case .trash:
                    TrashView()
                case .uninstaller:
                    UninstallerView()
                case .memory:
                    MemoryView()
                case nil:
                    DashboardView(selection: $selection)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }

    }
}

struct SidebarView: View {
    @Binding var selection: AppSection?
    @AppStorage("permanentDelete") private var permanentDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text("Ati Cleaner")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            VStack(spacing: 4) {
                ForEach(AppSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(section.tileColor)

                                Image(systemName: section.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 26, height: 26)

                            Text(section.title)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    selection == section
                                    ? Color.white.opacity(0.13)
                                    : Color.clear
                                )
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
        }
        .background(
            LinearGradient(
                colors: [Theme.navyDeep, Color(hex: 0x0B1D42)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color(hex: 0xFF6B81))
                    Toggle(isOn: $permanentDelete) {
                        Text("Kalıcı sil (geri alınamaz)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .toggleStyle(.checkbox)
                    .help("Açıkken silme işlemleri çöp kutusuna taşımadan doğrudan siler")
                }
                Text(permanentDelete ? "Silinenler çöp kutusuna gitmez" : "Silinenler çöp kutusuna taşınır")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.10))
            )
            .padding(10)
        }
    }
}