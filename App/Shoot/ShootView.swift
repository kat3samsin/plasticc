import PlasticcCore
import SwiftUI

/// The back of the camera: counter, finder, flash, wheel and shutter. No photo is ever shown.
struct ShootView: View {
    let model: RollModel
    @State private var blink = false

    private var roll: Roll? { model.roll }
    private var canWind: Bool { roll?.wound == false && !model.isCapturing }

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SNAPPY 35")
                        .font(.headline.weight(.black))
                    Text(model.film?.name ?? "")
                        .font(.caption)
                        .opacity(0.8)
                }
                .foregroundStyle(Plastic.trim)
                Spacer()
                CounterWindow(remaining: roll?.remaining ?? 0)
            }

            finder

            HStack {
                FlashSwitch(isOn: Bindable(model).flash)
                Spacer()
                VStack(spacing: 6) {
                    WindWheel(isEnabled: canWind) { model.wind() }
                    Text(canWind ? "WIND →" : "READY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Plastic.trim.opacity(0.8))
                }
            }

            ShutterButton(isArmed: roll?.wound == true) {
                Task { await model.shoot() }
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity)
        .background(Plastic.body)
        .task { await model.startCamera() }
        .onDisappear { model.stopCamera() }
        .onChange(of: model.shotCount) {
            blink = true
            withAnimation(.easeOut(duration: 0.3).delay(0.08)) { blink = false }
        }
    }

    /// Shows the scene the next press will take. On the simulator that's a sample photo.
    private var finder: some View {
        Color.black
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                if model.cameraAllowed == false {
                    PermissionView()
                } else if let live = model.camera as? LiveCamera {
                    CameraPreview(session: live.session)
                } else if let sample = model.camera as? SampleCamera, let image = sample.finderImage, model.shotCount >= 0 {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .overlay { Color.black.opacity(blink ? 1 : 0) }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Plastic.dark, lineWidth: 8)
            }
            .accessibilityHidden(model.cameraAllowed != false)
    }
}

private struct CounterWindow: View {
    let remaining: Int

    var body: some View {
        Text("\(remaining)")
            .font(.system(size: 26, weight: .bold, design: .monospaced))
            .foregroundStyle(Plastic.counter)
            .frame(width: 64, height: 44)
            .background(Plastic.dark, in: RoundedRectangle(cornerRadius: 22))
            .accessibilityLabel("\(remaining) exposures left")
    }
}

private struct FlashSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
            Feel.shared.notch()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(isOn ? Plastic.counter : Plastic.dark)
                    .frame(width: 12, height: 12)
                Text("FLASH")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(Plastic.trim)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Plastic.dark.opacity(0.5), in: Capsule())
        }
        .accessibilityLabel("Flash")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

private struct ShutterButton: View {
    let isArmed: Bool
    let action: () -> Void

    var body: some View {
        Button {
            if isArmed {
                Feel.shared.shutter()
                action()
            } else {
                Feel.shared.dud()
            }
        } label: {
            Circle()
                .fill(Plastic.trim)
                .frame(width: 84, height: 84)
                .overlay { Circle().strokeBorder(Plastic.dark, lineWidth: 6) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shutter")
        .accessibilityHint(isArmed ? "" : "Wind the film first")
    }
}
