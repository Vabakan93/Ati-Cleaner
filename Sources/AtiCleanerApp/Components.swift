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
