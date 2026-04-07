struct CategoryButton: View {
    let category: IconCategory
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? themeColor : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? themeColor : .primary)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(isSelected ? themeColor.opacity(0.15) : Color(.systemGray6))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? themeColor : Color.clear, lineWidth: 2)
                    )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}



