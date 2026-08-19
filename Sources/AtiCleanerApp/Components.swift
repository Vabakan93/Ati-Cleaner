import SwiftUI

struct PageHeader: View {
    let icon:String; let title:String; let subtitle:String; let tint:Color; let actionTitle:String?; let action:(()->Void)?
    init(icon:String,title:String,subtitle:String,tint:Color,actionTitle:String?=nil,action:(()->Void)?=nil){self.icon=icon;self.title=title;self.subtitle=subtitle;self.tint=tint;self.actionTitle=actionTitle;self.action=action}
    var body: some View {HStack(alignment:.top){ZStack{RoundedRectangle(cornerRadius:14).fill(tint);Image(systemName:icon).font(.title2).foregroundStyle(.white)}.frame(width:52,height:52);VStack(alignment:.leading,spacing:4){Text(title).font(.largeTitle.bold());Text(subtitle).foregroundStyle(.secondary)};Spacer();if let actionTitle,let action{Button(actionTitle,action:action).buttonStyle(.borderedProminent).tint(tint)}}}
}

struct ReadyRing: View { let icon:String; let title:String; let detail:String; let tint:Color
    var body: some View {ZStack{Circle().stroke(Color.secondary.opacity(0.14),lineWidth:16);Circle().trim(from:0,to:0.72).stroke(tint,style:StrokeStyle(lineWidth:16,lineCap:.round)).rotationEffect(.degrees(-90));VStack(spacing:5){Image(systemName:icon).font(.system(size:28,weight:.semibold)).foregroundStyle(tint);Text(title).font(.headline);Text(detail).font(.caption).foregroundStyle(.secondary)}}.frame(width:170,height:170)}
}

struct InfoTile: View {let icon:String;let title:String;let subtitle:String;let tint:Color
    var body: some View {VStack(spacing:9){ZStack{RoundedRectangle(cornerRadius:10).fill(tint.opacity(0.12));Image(systemName:icon).font(.title2).foregroundStyle(tint)}.frame(width:46,height:46);Text(title).font(.headline);Text(subtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)}.frame(maxWidth:.infinity).padding(14).background(RoundedRectangle(cornerRadius:14).fill(Color(nsColor:.controlBackgroundColor)))}
}

struct RiskTag: View {
    let isUnnecessary: Bool
    var body: some View {
        Label("Gereksiz", systemImage: "checkmark.circle.fill")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(Color.green.opacity(0.18)))
            .foregroundStyle(.green)
            .opacity(isUnnecessary ? 1 : 0)
    }
}

struct DeleteBar: View {
    let selectedCount: Int
    let totalCount: Int
    let selectedSize: Int64
    let permanent: Bool
    let onToggleAll: @Sendable (Bool) -> Void
    let onDelete: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { totalCount > 0 && selectedCount == totalCount }, set: onToggleAll))
                .labelsHidden()
                .toggleStyle(.checkbox)
            Text("\(selectedCount)/\(totalCount) öğe seçildi")
                .font(.headline)
            Text("• \(selectedSize.formattedBytes)")
                .foregroundStyle(.secondary)
            Spacer()
            if permanent {
                Button(role: .destructive, action: onDelete) { Label("Kalıcı Sil", systemImage: "trash.slash") }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(selectedCount == 0)
            } else {
                Button(action: onDelete) { Label("Çöp Kutusu'na Taşı", systemImage: "trash") }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(selectedCount == 0)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

extension View {
    func revealInFinder(_ path: String) -> some View {
        contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            } label: {
                Label("Finder'da Göster", systemImage: "folder")
            }
        }
    }
}
