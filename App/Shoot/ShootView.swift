import PlasticcCore
import SwiftUI

/// The back of the camera: counter, finder, flash, wheel and shutter. No photo is ever shown.
struct ShootView: View {
    let model: RollModel
    @State private var blink = false
    @Environment(\.scenePhase) private var scenePhase

    private var roll: Roll? { model.roll }
    private var brand: FilmBrand { (model.film ?? .superia400).brand }
    private var canWind: Bool { roll?.wound == false && !model.isCapturing }

    var body: some View {
        ZStack {
            CameraBack(brand: brand)

            VStack(spacing: 14) {
                header

                Finder(model: model, blink: blink)
                    .frame(maxHeight: 360)

                band

                HStack(alignment: .bottom) {
                    FlashSwitch(state: model.flashState, ink: brand.ink) { model.setFlash($0) }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 7) {
                        Text(canWind ? "TURN WHEEL UNTIL IT STOPS" : "READY")
                            .font(.print(10))
                            .tracking(1)
                            .foregroundStyle(brand.ink.opacity(0.9))
                            .swaps(on: canWind)
                        WindWheel(isEnabled: canWind) { model.wind() }
                    }
                }
                .padding(.horizontal, 6)

                Spacer(minLength: 0)

                ShutterButton(isArmed: roll?.wound == true, ring: brand.band) {
                    await model.shoot()
                }

                Text("DO NOT OPEN BACK · RETURN CAMERA TO LAB")
                    .font(.print(9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(brand.ink.opacity(0.55))
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
            VStack(alignment: .leading, spacing: 0) {
                Text(brand.maker)
                    .font(.print(13))
                    .tracking(3)
                Text(brand.line)
                    .font(.print(26))
                    .italic()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("\(brand.speed) · \(roll?.length.exposures ?? 0) EXP")
                    .font(.print(12, weight: .heavy))
                    .tracking(1)
                    .opacity(0.85)
            }
            .foregroundStyle(brand.ink)
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

    private var band: some View {
        Text("SNAPPY 35 · SINGLE-USE CAMERA WITH FLASH")
            .font(.print(10))
            .tracking(1.4)
            .foregroundStyle(brand.bandInk)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(brand.band, in: Capsule())
    }
}
