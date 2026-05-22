import SwiftUI

struct ExportModePanel: View {
    @Binding var selectedMode: ScanExportMode
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PDF export")
                .font(.headline)

            Picker("PDF export mode", selection: $selectedMode) {
                ForEach(ScanExportMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
