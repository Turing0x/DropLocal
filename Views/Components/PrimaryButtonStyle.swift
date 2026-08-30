import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(TDDColor.ctaPrimaryFg)
            .background(
                LinearGradient(
                    colors: [TDDColor.ctaPrimaryBg, TDDColor.ctaPrimaryBgHover],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: TDDRadius.xl))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(TDDMotion.easeOut(TDDMotion.fast), value: configuration.isPressed)
    }
}
