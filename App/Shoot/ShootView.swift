import AVKit
import PlasticcCore
import SwiftUI

/// The back of the camera: counter, finder, flash, wheel and shutter. No photo is ever shown.
struct ShootView: View {
    let model: RollModel
    @State private var blink = false
    @Environment(\.scenePhase) private var scenePhase

    private var roll: Roll? { model.roll }
    private var canWind: Bool { roll?.wound == false && !model.isCapturing }

    var body: some View {
        ZStack {
            CameraBack()

            VStack(spacing: 14) {
                header

                Finder(model: model, blink: blink)
                    .frame(maxHeight: 360)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        FlashSwitch(state: model.flashState, ink: Plastic.trim) { model.setFlash($0) }
                        MultiSwitch(isOn: model.multi, isEnabled: model.canFlipMulti, blockedReason: model.multiBlockedReason,
                                    ink: Plastic.trim) { model.setMulti($0) }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 7) {
                        Text(model.isCapturing ? "SAVING…"
                             : canWind ? (model.multi ? "TURN WHEEL TO COCK" : "TURN WHEEL UNTIL IT STOPS") : "READY")
                            .font(.print(10))
                            .tracking(1)
                            .foregroundStyle(Plastic.trim.opacity(0.9))
                            .swaps(on: canWind)
                        WindWheel(isEnabled: canWind) { model.wind() }
                    }
                }
                // The same inset as the header, so the flash lines up under the name and the wheel under the counter.
                .padding(.horizontal, 4)

                Spacer(minLength: 0)

                ShutterButton(isArmed: roll?.wound == true, ring: Plastic.accent) {
                    await model.shoot()
                }

                Text("DO NOT OPEN BACK UNTIL FILM IS REWOUND")
                    .font(.print(9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Plastic.trim.opacity(0.45))
            }
            .padding(.horizontal, 26)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .task { await model.startCamera() }
        // Back from Settings after allowing the camera.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, model.cameraAllowed == false { Task { await model.startCamera() } }
        }
        .onDisappear { model.stopCamera() }
        // The volume buttons and Camera Control fire the shutter too, on release, like the button on screen.
        .onCameraCaptureEvent { event in
            guard event.phase == .ended else { return }
            pressShutter()
        }
        // The shutter blinks the finder the moment it fires, not when the phone has finished saving the photo.
        .onChange(of: model.isCapturing) { _, capturing in
            guard capturing else { return }
            blink = true
            withAnimation(.easeOut(duration: 0.3).delay(0.08)) { blink = false }
        }
        .animation(.easeInOut(duration: 0.2), value: canWind)
        .animation(.easeInOut(duration: 0.25), value: model.multi)
        .animation(.easeOut(duration: 0.15), value: model.isCapturing)
    }

    /// The shutter pressed from a hardware button: a shot if the film is wound, the dead stop if not.
    private func pressShutter() {
        guard roll?.wound == true, !model.isCapturing else {
            Feel.shared.locked()
            return
        }
        Feel.shared.shutter()
        Task { if await !model.shoot() { Feel.shared.dud() } }
    }

    private var header: some View {
        HStack(alignment: .center) {
            // The camera's name moulded into the plastic, and the window onto the canister inside.
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    Text("SNAPPY")
                        .foregroundStyle(Plastic.trim)
                    Text(" 35")
                        .foregroundStyle(Plastic.accent)
                }
                .font(.print(26))
                .italic()
                Text("35MM · FOCUS FREE · FLASH")
                    .font(.print(8, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Plastic.trim.opacity(0.5))
                FilmWindow(film: model.film)
            }
            Spacer()
            SelfieSwitch(isOn: model.isFront, ink: Plastic.trim) { model.setFront($0) }
                .padding(.trailing, 14)
            CounterDisc(remaining: roll?.remaining ?? 0)
                #if DEBUG
                // Hold the counter to fill the rest of the roll (debug builds only).
                .onLongPressGesture(minimumDuration: 1) {
                    Feel.shared.windStop()
                    Task { await model.finishRollForTesting() }
                }
                #endif
        }
        .padding(.horizontal, 4)
    }
}
