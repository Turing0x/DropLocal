import SwiftUI

struct RootView: View {
    @State private var viewModel = HomeViewModel()
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            TDDColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case 1:
                        ReceiveView()
                    case 2:
                        ActivityView(records: viewModel.records)
                    default:
                        SendView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                    .overlay(TDDColor.border)

                HStack {
                    TabButton(title: "Enviar", systemImage: "arrow.up.circle.fill", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: "Recibir", systemImage: "arrow.down.circle.fill", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    TabButton(title: "Actividad", systemImage: "clock.arrow.circlepath", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                }
                .padding(.horizontal, TDDSpacing.s16)
                .padding(.top, TDDSpacing.s12)
                .padding(.bottom, TDDSpacing.s8)
                .background(TDDColor.card.opacity(0.96))
            }
        }
    }
}
