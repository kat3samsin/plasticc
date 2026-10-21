import PlasticcCore
import SwiftUI

/// The lab order form: how long developing takes, the date stamp, and sounds.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Settings.developTimeKey) private var developTime = DevelopTime.hour
    @AppStorage(Settings.dateStampKey) private var dateStamp = true
    @AppStorage(Settings.soundsKey) private var sounds = true

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Text("Lab order")
                            .font(.print(30))
                        Spacer()
                        Button("Done") { dismiss() }
                            .font(.print(16, weight: .heavy))
                    }
                    .foregroundStyle(Paper.ink)

                    section("DEVELOP TIME") {
                        VStack(spacing: 0) {
                            ForEach(DevelopTime.allCases, id: \.self) { option in
                                Button {
                                    Feel.shared.click()
                                    developTime = option
                                    if option != .instant { Task { await LabNotice.requestPermission() } }
                                } label: {
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: developTime == option ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 22))
                                            .foregroundStyle(developTime == option ? Paper.stampRed : Paper.fadedInk)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(option.title).font(.typed(18))
                                            Text(option.detail).font(.typed(13)).foregroundStyle(Paper.fadedInk)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(developTime == option ? .isSelected : [])
                                if option != DevelopTime.allCases.last { dashed }
                            }
                        }
                    }

                    section("ON EVERY PRINT") {
                        Toggle(isOn: $dateStamp) {
                            HStack(spacing: 14) {
                                Text("'26 10 20")
                                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                    .italic()
                                    .foregroundStyle(Plastic.counter)
                                    .shadow(color: Plastic.counter.opacity(0.8), radius: 3)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 4))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Date stamp").font(.typed(18))
                                    Text("Orange digits in the corner, like the date back.").font(.typed(13)).foregroundStyle(Paper.fadedInk)
                                }
                            }
                        }
                        .tint(Paper.stampRed)
                    }

                    section("THE CAMERA") {
                        Toggle(isOn: $sounds) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sounds").font(.typed(18))
                                Text("Clicks, whines and clunks. The silent switch mutes them too.").font(.typed(13)).foregroundStyle(Paper.fadedInk)
                            }
                        }
                        .tint(Paper.stampRed)
                    }

                    Text("Changes apply to rolls developed after you make them.")
                        .font(.typed(13))
                        .foregroundStyle(Paper.fadedInk)
                }
                .foregroundStyle(Paper.ink)
                .padding(24)
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.print(11))
                .tracking(2)
                .foregroundStyle(Paper.stampRed)
            content()
                .padding(16)
                .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Paper.ink.opacity(0.12), lineWidth: 1))
        }
    }

    private var dashed: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 1)
            .overlay(Rectangle().stroke(Paper.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}
