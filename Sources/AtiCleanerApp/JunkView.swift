import SwiftUI
import AtiCleanerCore

@MainActor final class JunkVM: ObservableObject { @Published var categories:[JunkCategory]=[];@Published var scanning=false;@Published var progress=ScanProgress(phase:"Hazır")
    func scan(){guard !scanning else{return};scanning=true;Task{let found=await Task.detached{JunkScanner().scan(progress:{p in Task{@MainActor in self.progress=p}},isCancelled:{false})}.value;categories=found;scanning=false}}
    var total:Int64{categories.flatMap(\.items).reduce(0){$0+$1.size}}
}
struct JunkView: View {@StateObject private var vm=JunkVM()
    var body: some View {VStack(alignment:.leading,spacing:18){PageHeader(icon:"paintbrush.fill",title:"Sistem Çöpü",subtitle:"Bilinen kullanıcı önbellekleri, günlükler ve geçici kalıntıları tarayın.",tint:Theme.junk,actionTitle:"Tara",action:vm.scan);if vm.scanning{ProgressView(vm.progress.phase)}else if vm.categories.isEmpty{VStack(spacing:18){ReadyRing(icon:"paintbrush.fill",title:"Taramaya Hazır",detail:"Güvenli kullanıcı alanları",tint:Theme.junk);HStack{InfoTile(icon:"shippingbox",title:"Önbellekler",subtitle:"Uygulamaların yeniden oluşturabildiği veriler",tint:Theme.junk);InfoTile(icon:"doc.text",title:"Günlükler",subtitle:"Eski uygulama günlükleri",tint:Theme.junk);InfoTile(icon:"shield.checkered",title:"Güvenli Politika",subtitle:"Sistem kökleri dışarıda bırakılır",tint:Theme.junk)}.frame(maxWidth:820)}.frame(maxWidth:.infinity)}else{Text("Bulunan toplam: \(vm.total.formattedBytes)").font(.title2.bold());List(vm.categories){cat in Section("\(cat.name) — \(cat.totalSize.formattedBytes)"){ForEach(cat.items){item in HStack{Image(systemName:item.isDirectory ? "folder":"doc");Text(item.name);Spacer();Text(item.size.formattedBytes).foregroundStyle(.secondary)}}}}}}.padding(24)} }
