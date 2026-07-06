import SwiftUI

struct EditableLabRowView: View {
    @Binding var draft: EditableLabDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: $draft.isSelected) {
                    Text(draft.displayLabel)
                        .font(.subheadline.bold())
                }
            }

            HStack(spacing: 8) {
                TextField("数值", text: $draft.value)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 90)

                TextField("单位", text: $draft.unit)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)

                TextField("下限", text: $draft.refRangeLow)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)

                Text("–")

                TextField("上限", text: $draft.refRangeHigh)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EditableLabRowView(draft: .constant(EditableLabDraft(labType: "CEA", value: "5.20", unit: "ng/mL")))
        .padding()
}
