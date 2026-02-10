import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let action: (() -> Void)?
    let actionLabel: String?
    
    init(icon: String, title: String, message: String, action: (() -> Void)? = nil, actionLabel: String? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.action = action
        self.actionLabel = actionLabel
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            if let action, let actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
