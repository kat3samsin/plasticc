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
                    FlashSwitch(state: model.flashState, ink: Plastic.trim) { model.setFlash($0) }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 7) {
                        Text(canWind ? "TURN WHEEL UNTIL IT STOPS" : "READY")
                            .font(.print(10))
                            .tracking(1)
                            .foregroundStyle(Plastic.trim.opacity(0.9))
                            .swaps(on: canWind)
                        WindWheel(isEnabled: canWind) { model.wind() }
                    }
                }
                .padding(.horizontal, 6)

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
        .onChange(of: model.shotCount) {
            blink = true
            withAnimation(.easeOut(duration: 0.3).delay(0.08)) { blink = false }
        }
        .animation(.easeInOut(duration: 0.2), value: canWind)
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
