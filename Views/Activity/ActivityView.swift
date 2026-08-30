import SwiftUI

struct ActivityView: View {
    let records: [TransferRecord]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TDDSpacing.s20) {
                    HeaderView(
                        eyebrow: "HISTORIAL",
                        title: "Tu actividad.",
                        subtitle: "Un vistazo a tus transferencias recientes."
                    )

                    if records.isEmpty {
                        EmptyStateView(
                            icon: "clock.arrow.circlepath",
                            title: "Sin transferencias todavía",
                            message: "Cuando envíes un archivo, verás aquí el estado y el dispositivo de destino."
                        )
                    } else {
                        VStack(spacing: TDDSpacing.s8) {
                            ForEach(records) { record in
                                TransferProgressRow(record: record)
                            }
                        }
                    }
                }
                .padding(TDDSpacing.s20)
            }
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
