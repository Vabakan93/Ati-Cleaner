import SwiftUI
import AtiCleanerCore

enum AppSection: String, CaseIterable, Identifiable {
    case overview, junk, large, duplicates, trash, uninstaller, memory, system
    var id:String{rawValue}
    var title:String{switch self{case .overview:"Genel Bakış";case .junk:"Sistem Çöpü";case .large:"Büyük Dosyalar";case .duplicates:"Çift Dosyalar";case .trash:"Çöp Kutusu";case .uninstaller:"Uygulama Kaldırıcı";case .memory:"Bellek";case .system:"Sistem Verisi"}}
    var icon:String{switch self{case .overview:"gauge";case .junk:"paintbrush.fill";case .large:"doc.richtext";case .duplicates:"doc.on.doc";case .trash:"trash";case .uninstaller:"xmark.app";case .memory:"memorychip";case .system:"internaldrive.fill"}}
    var tint:Color{switch self{case .overview:Theme.accent;case .junk:Theme.junk;case .large:Theme.large;case .duplicates:Theme.duplicates;case .trash:Theme.trash;case .uninstaller:Theme.uninstall;case .memory:Theme.memory;case .system:Theme.system}}
}

struct RootView: View {
    @State private var selection: AppSection = .overview
    @State private var fdaGranted = true
    @AppStorage("permanentDelete") private var permanentDelete=false
    var body: some View {
        VStack(spacing: 0) {
            if !fdaGranted {
                HStack(spacing: 10) {
                    Image(systemName: "folder.badge.gearshape").font(.title3).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tam Disk Erişimi gerekli").font(.headline)
                        Text("Tek seferlik ayar: Sistem Ayarları → Gizlilik ve Güvenlik → Tam Disk Erişimi'nde 'Ati Cleaner' anahtarını açın, sonra uygulamayı yeniden başlatın. Böylece taramalar artık izin sormaz.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Aç") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.12)))
                .padding(12)
            }
        HStack(spacing:0){
            VStack(alignment:.leading,spacing:0){
                HStack(spacing:10){
                    Image(systemName:"sparkles.rectangle.stack.fill").font(.title2).foregroundStyle(.white)
                    Text("Ati Cleaner").font(.system(size:18,weight:.heavy)).foregroundStyle(.white)
                }.padding(16)
                VStack(spacing:4){ForEach(AppSection.allCases){section in Button{selection=section}label:{HStack(spacing:10){ZStack{RoundedRectangle(cornerRadius:7).fill(section.tint);Image(systemName:section.icon).foregroundStyle(.white)}.frame(width:27,height:27);Text(section.title).font(.system(size:13.5,weight:.semibold));Spacer()}.padding(.horizontal,10).frame(height:38).foregroundStyle(.white).background(RoundedRectangle(cornerRadius:8).fill(selection==section ? Color.white.opacity(0.14):.clear))}.buttonStyle(.plain)}}.padding(.horizontal,8)
                Spacer()
                VStack(alignment:.leading,spacing:6){Toggle("Kalıcı sil (geri alınamaz)",isOn:$permanentDelete).toggleStyle(.checkbox);Text(permanentDelete ? "Silinenler doğrudan kaldırılır" : "Silinenler Çöp Kutusu'na taşınır").font(.caption).foregroundStyle(.white.opacity(0.65))}.foregroundStyle(.white).padding(12).background(RoundedRectangle(cornerRadius:12).fill(Color.white.opacity(0.08))).padding(10)
            }.frame(width:230).background(LinearGradient(colors:[Theme.navy,Color(red:0.03,green:0.11,blue:0.25)],startPoint:.top,endPoint:.bottom))
            Group{switch selection{case .overview:OverviewView();case .junk:JunkView();case .large:LargeFilesView();case .duplicates:DuplicatesView();case .trash:TrashView();case .uninstaller:UninstallerView();case .memory:MemoryView();case .system:SystemDataView()}}.frame(maxWidth:.infinity,maxHeight:.infinity)
        }
        .task {
            fdaGranted = await Task.detached { () -> Bool in PrivilegedHelper.fullDiskAccessGranted() }.value
        }
        }
    }
}
