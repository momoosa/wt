import SwiftUI
import SwiftData
import WeektimeKit

struct IntervalListSelector: View {
    let lists: [IntervalListSession]
    @Binding var selectedListID: String?
    let tintColor: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(lists) { list in
                    Text(list.list.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(selectedListID == list.id ? .white : tintColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedListID == list.id ? tintColor : tintColor.opacity(0.1))
                        )
                        .contentShape(Capsule())
                        .onTapGesture {
                            selectedListID = list.id
                        }
                }
            }
            .padding(.horizontal, 8)
            .animation(.easeInOut, value: selectedListID)
        }
        .frame(height: 40)
    }
}
