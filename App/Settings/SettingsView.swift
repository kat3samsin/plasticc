import PlasticcCore
import SwiftUI

/// The lab order form: how long developing takes, the date stamp, and sounds.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Settings.developTimeKey) private var developTime = DevelopTime.hour
    @AppStorage(Settings.dateStampKey) private var dateStamp = true
    @AppStorage(Settings.soundsKey) private var sounds = true
    @AppStorage(Settings.quickLoadKey) private var quickLoad = false
    @AppStorage(Settings.quickDevelopKey) private var quickDevelop = false
    @AppStorage(Settings.glowKey) private var glow = false
    @AppStorage(Settings.lightLeaksKey) private var lightLeaks = true
    @AppStorage(Settings.printFormatKey) private var printFormat = PrintFormat.classic

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
                            .frame(minWidth: Layout.tap, minHeight: Layout.tap, alignment: .trailing)
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
                        VStack(spacing: 0) {
                            Toggle(isOn: $dateStamp) {
                                HStack(spacing: 14) {
                                    thumb {
                                        Text("'26 10 20")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .italic()
                                            .foregroundStyle(Plastic.counter)
                                            .shadow(color: Plastic.counter.opacity(0.8), radius: 3)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Date stamp").font(.typed(18))
                                        Text("Orange digits in the corner, like the date back.").font(.typed(13)).foregroundStyle(Paper.fadedInk)
                                    }
                                }
                            }
                            .toggleStyle(PaperToggleStyle())
                            dashed.padding(.vertical, 12)
                            Toggle(isOn: $glow) {
                                HStack(spacing: 14) {
                                    thumb {
                                        Circle()
                                            .fill(RadialGradient(colors: [.white, Plastic.lamp.opacity(0.5), .clear], center: .center, startRadius: 1, endRadius: 22))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Glow").font(.typed(18))
                                        Text("A soft bloom around lights and highlights, like a diffusion filter.").font(.typed(13)).foregroundStyle(Paper.fadedInk)
                                    }
                                }
                            }
                            .toggleStyle(PaperToggleStyle())
                            dashed.padding(.vertical, 12)
                            Toggle(isOn: $lightLeaks) {
                                HStack(spacing: 14) {
                                    thumb {
                                        LinearGradient(colors: [Color(red: 1, green: 0.45, blue: 0.2), Color(red: 1, green: 0.3, blue: 0.5).opacity(0.6), .clear],
                                                       startPoint: .leading, endPoint: .trailing)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Light leaks").font(.typed(18))
                                        Text("Warm glows on the odd frame, most often the first two, as on a cheap camera.").font(.typed(13)).foregroundStyle(Paper.fadedInk)
                                    }
                                }
                            }
                            .toggleStyle(PaperToggleStyle())
                            dashed.padding(.vertical, 12)
                            formatPicker
                        }
                    }

                    section("THE CAMERA") {
                        VStack(spacing: 0) {
                            Toggle(isOn: $sounds) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sounds").font(.typed(18))
                                    Text("Clicks, whines and clunks. The silent switch mutes them too.").font(.typed(13)).foregroundStyle(Paper.fadedInk)
                                }
                            }
                            .toggleStyle(PaperToggleStyle())
                            dashed.padding(.vertical, 12)
                            Toggle(isOn: $quickLoad) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Quick load").font(.typed(18))
                                    Text("Skip opening the box and loading the film. A new roll goes straight into the camera.").font(.typed(13)).foregroundStyle(Paper.fadedInk)
                                }
                            }
                            .toggleStyle(PaperToggleStyle())
                            dashed.padding(.vertical, 12)
                            Toggle(isOn: $quickDevelop) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Quick develop").font(.typed(18))
                                    Text("Skip the crank and the lab. The last frame goes straight to the darkroom.").font(.typed(13)).foregroundStyle(Paper.fadedInk)
                                }
                            }
                            .toggleStyle(PaperToggleStyle())
                        }
                    }

                    Text("Changes apply to rolls developed after you make them.")
                        .font(.typed(13))
                        .foregroundStyle(Paper.fadedInk)
                }
                .foregroundStyle(Paper.ink)
                .padding(Layout.margin)
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
    }

    /// The print's shape: three little print outlines to tick, like the boxes on a lab order.
    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Print format").font(.typed(18))
                Text("The shape the lab crops each print to.").font(.typed(13)).foregroundStyle(Paper.fadedInk)
            }
            HStack(spacing: 12) {
                ForEach(PrintFormat.allCases, id: \.self) { format in
                    Button {
                        Feel.shared.click()
                        printFormat = format
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(printFormat == format ? Paper.stampRed : Paper.fadedInk, lineWidth: 2)
                                .frame(width: 34 / format.ratio, height: 34)
                                .frame(height: 38)
                            Text(format.rawValue).font(.typed(14))
                            Text(Self.formatName(format)).font(.typed(11)).foregroundStyle(Paper.fadedInk)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(printFormat == format ? Paper.stampRed.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(format.rawValue), \(Self.formatName(format))")
                    .accessibilityAddTraits(printFormat == format ? .isSelected : [])
                }
            }
        }
    }

    private static func formatName(_ format: PrintFormat) -> String {
        switch format {
        case .classic: "35 mm"
        case .phone: "Phone"
        case .square: "Square"
        }
    }

    /// A little dark swatch showing what a print setting does, all one size so the rows' text lines up.
    private func thumb<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 64, height: Layout.tap)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
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
