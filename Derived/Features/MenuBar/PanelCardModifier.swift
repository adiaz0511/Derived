import SwiftUI

struct PanelCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: .rect(cornerRadius: DesignMetrics.cardCornerRadius))
            .clipShape(.rect(cornerRadius: DesignMetrics.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: DesignMetrics.cardCornerRadius)
                    .stroke(.quaternary, lineWidth: 1)
            }
    }
}

extension View {
    func panelCard() -> some View {
        modifier(PanelCardModifier())
    }
}
