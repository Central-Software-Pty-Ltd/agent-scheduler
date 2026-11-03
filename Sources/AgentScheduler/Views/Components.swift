import AppKit
import SwiftUI

struct Row<Content: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false
    var icon: String?
    var shortcut: KeyEquivalent?
    let action: () -> Void
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).frame(width: 16) }
                content(hovering && isEnabled)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering && isEnabled ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? .primary : .tertiary)
        .onHover { hovering = $0 }
        .keyboardShortcut(shortcut.map { KeyboardShortcut($0) })
    }
}

struct Separator: View {
    var body: some View {
        Divider().padding(.horizontal, 10).padding(.vertical, 5)
    }
}

struct Hint: View {
    let text: String

    var body: some View {
        Text(text).foregroundStyle(.tertiary).lineLimit(1)
    }
}

struct StatusDot: View {
    let on: Bool
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(on ? Color.green : Color.secondary.opacity(0.5))
            .frame(width: size, height: size)
    }
}

struct Chip: View {
    let title: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(on ? .primary : .secondary)
                .background(on ? Color.primary.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct DayToggle: View {
    let letter: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(.caption)
                .frame(width: 24, height: 24)
                .foregroundStyle(on ? Color(nsColor: .windowBackgroundColor) : .secondary)
                .background(on ? Color.primary : .clear, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(on ? .clear : Color.primary.opacity(0.15)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    if row.id != rows.first?.id { Divider().padding(.leading, 56) }
                    row
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

struct ServiceRow<Trailing: View>: View {
    let tile: Tile
    let title: String
    let detail: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            tile
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct Tile: View {
    var symbol: String?
    var image: String?

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(LinearGradient(colors: [Color(white: 0.34), Color(white: 0.12)], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.12)))
            .frame(width: 30, height: 30)
            .overlay {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                } else if let image {
                    Image(image).renderingMode(.template).resizable().frame(width: 14, height: 14)
                }
            }
            .foregroundStyle(.white)
    }
}

struct Done: View {
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text(title).foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
    }
}

struct Pill: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    var busy = false
    let action: () -> Void

    var body: some View {
        if busy {
            ProgressView().controlSize(.small)
        } else {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(isEnabled ? 0.08 : 0.04), in: Capsule())
                    .foregroundStyle(isEnabled ? .primary : .tertiary)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 40)
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            .background(Color.primary.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.25), in: shape)
            .contentShape(shape)
    }
}

struct WindowFitter: NSViewRepresentable {
    let height: CGFloat

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        Task { @MainActor in
            guard let window = view.window, let content = window.contentView else { return }
            let target = window.frame.height - content.frame.height + content.fittingSize.height
            guard abs(window.frame.height - target) > 0.5 else { return }
            var frame = window.frame
            frame.origin.y = frame.maxY - target
            frame.size.height = target
            window.setFrame(frame, display: true)
        }
    }
}
