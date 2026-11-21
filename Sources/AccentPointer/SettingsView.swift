import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    var requestPermission: () -> Void
    var openPermissions: () -> Void
    var preview: () -> Void
    var quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 16) {
                    PreviewCard(preferences: preferences, preview: preview)
                    cursorSettings
                    keyboardSettings
                }
                .padding(.horizontal, 26)
                .padding(.top, 8)
                .padding(.bottom, 22)
            }
            footer
        }
        .frame(minWidth: 590, idealWidth: 640, maxWidth: .infinity, minHeight: 660)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.07)))
                Image(systemName: "cursorarrow.rays").font(.system(size: 26, weight: .medium)).foregroundStyle(preferences.tint.color)
            }.frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text("Акцент").font(.system(size: 29, weight: .semibold, design: .rounded))
                Text("Помогает следить за вашей мыслью.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                preferences.running.toggle()
            } label: {
                Label(preferences.running ? "Пауза" : "Включить", systemImage: preferences.running ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(minWidth: 78)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(preferences.running ? Color(nsColor: .controlAccentColor) : .green)
            .help("Скрыть или включить все эффекты · ⌃⌥P")
            .accessibilityIdentifier("masterToggle")
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }

    private var cursorSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            featureHeader("Курсор", detail: "Прозрачный центр. Всё под ним видно.", icon: "cursorarrow", enabled: $preferences.ringEnabled)
            VStack(spacing: 12) {
                sliderRow("Размер", value: $preferences.radius, range: 16...48, valueText: "\(Int(preferences.radius * 2))")
                sliderRow("Толщина", value: $preferences.lineWidth, range: 1.5...5, valueText: String(format: "%.1f", preferences.lineWidth))
                sliderRow("Яркость", value: $preferences.opacity, range: 0.35...1, valueText: "\(Int(preferences.opacity * 100))%")
                HStack {
                    Text("Цвет").font(.system(size: 12)).frame(width: 76, alignment: .leading)
                    ForEach(PointerTint.allCases) { tint in
                        Button { preferences.tint = tint } label: {
                            Circle().fill(tint.color)
                                .overlay(Circle().strokeBorder(.primary.opacity(0.18), lineWidth: 0.75))
                                .frame(width: 18, height: 18)
                                .padding(4)
                                .overlay(Circle().strokeBorder(preferences.tint == tint ? Color.primary.opacity(0.6) : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .help(tint.title)
                        .accessibilityLabel(tint.title)
                        .accessibilityAddTraits(preferences.tint == tint ? .isSelected : [])
                    }
                    Spacer()
                    Text(preferences.tint.title).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .disabled(!preferences.ringEnabled)
            Divider().opacity(0.6)
            featureHeader("Клики", detail: "Отдельный цвет для каждой кнопки.", icon: "dot.radiowaves.left.and.right", enabled: $preferences.clicksEnabled)
            VStack(spacing: 12) {
                HStack(spacing: 24) {
                    clickColorControl(right: false)
                    Divider().frame(height: 32)
                    clickColorControl(right: true)
                }
                HStack {
                    Spacer()
                    Button("Сбросить цвета") {
                        preferences.leftClickHex = nil
                        preferences.rightClickHex = nil
                    }
                    .buttonStyle(.link).font(.system(size: 11))
                    .disabled(preferences.leftClickHex == nil && preferences.rightClickHex == nil)
                }
            }
            .padding(.leading, 35)
            .disabled(!preferences.clicksEnabled)
        }.settingsCard()
    }

    private func clickColorControl(right: Bool) -> some View {
        let color = Color(nsColor: right ? preferences.rightClickColor : preferences.leftClickColor)
        let title = right ? "Правый клик" : "Левый клик"
        let selection = Binding<Color>(get: {
            Color(nsColor: right ? preferences.rightClickColor : preferences.leftClickColor)
        }, set: { selected in
            let hex = Preferences.hex(from: NSColor(selected))
            if right { preferences.rightClickHex = hex } else { preferences.leftClickHex = hex }
        })
        return HStack(spacing: 9) {
            ZStack {
                Circle().strokeBorder(color, lineWidth: 1.5)
                if right { Circle().strokeBorder(color, lineWidth: 1.2).padding(3) }
            }.frame(width: 17, height: 17)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(right ? "Две волны" : "Одна волна").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            ColorPicker(title, selection: selection, supportsOpacity: false)
                .labelsHidden().fixedSize()
                .accessibilityLabel("Цвет: \(title.lowercased())")
                .help("Выбрать цвет: \(title.lowercased())")
        }.frame(maxWidth: .infinity)
    }

    private var keyboardSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            featureHeader("Сочетания клавиш", detail: "Только команды. Обычный текст не показывается.", icon: "command", enabled: $preferences.keysEnabled)
            if preferences.keysEnabled {
                if !preferences.inputAllowed {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "keyboard.badge.ellipsis").font(.system(size: 21)).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Нужно разрешение macOS").font(.system(size: 12, weight: .medium))
                            Text("Включите «Акцент» в «Мониторинге ввода».")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button("Разрешить", action: requestPermission).controlSize(.regular)
                            .accessibilityIdentifier("grantInput")
                    }
                    .padding(12)
                    .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                } else if preferences.secureInput {
                    Label("Защищённый ввод — сочетания временно скрыты.", systemImage: "lock.shield")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else if !preferences.inputWorking && preferences.running {
                    HStack {
                        Label("macOS ещё не подключила клавиатуру.", systemImage: "exclamationmark.circle")
                        Spacer()
                        Button("Настройки", action: openPermissions)
                    }.font(.system(size: 11)).foregroundStyle(.secondary)
                }
                HStack {
                    Text("Положение").font(.system(size: 12)).frame(width: 90, alignment: .leading)
                    Picker("Положение", selection: $preferences.hudPosition) {
                        ForEach(HUDPosition.allCases) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(maxWidth: 220)
                    Spacer()
                }
                sliderRow("Длительность", value: $preferences.hudDuration, range: 0.6...4,
                          valueText: String(format: "%.1f с", preferences.hudDuration), labelWidth: 90)
            }
        }.settingsCard()
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Circle().fill(preferences.running ? Color.green : Color.secondary).frame(width: 6, height: 6)
                Text(preferences.running ? "Эффекты включены" : "Все эффекты на паузе")
                Spacer()
                if preferences.hotkeyAvailable {
                    Text("Пауза / пуск").foregroundStyle(.secondary)
                    Text("⌃ ⌥ P").font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
                } else {
                    Text("⌃⌥P занято другой программой").foregroundStyle(.secondary)
                }
                Divider().frame(height: 14).padding(.horizontal, 5)
                Button("Выйти", action: quit).buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .font(.system(size: 11))
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
        }
    }

    private func featureHeader(_ title: String, detail: String, icon: String, enabled: Binding<Bool>) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 18, weight: .regular)).foregroundStyle(.secondary).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: enabled).labelsHidden().toggleStyle(.switch).controlSize(.small)
                .accessibilityLabel(title)
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, valueText: String, labelWidth: CGFloat = 76) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 12)).frame(width: labelWidth, alignment: .leading)
            Slider(value: value, in: range).accessibilityLabel(title).controlSize(.small)
            Text(valueText).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 46, alignment: .trailing)
        }
    }
}

private extension View {
    func settingsCard() -> some View {
        self.padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.055), lineWidth: 0.75))
    }
}

struct PreviewCard: View {
    @ObservedObject var preferences: Preferences
    var preview: () -> Void
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color(nsColor: .controlAccentColor).opacity(0.12),
                    Color(nsColor: .systemTeal).opacity(0.09), Color(nsColor: .controlBackgroundColor)], startPoint: .topLeading, endPoint: .bottomTrailing))
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ничего лишнего", systemImage: "sparkle")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Text("Внимание на главном.")
                        .font(.system(size: 21, weight: .medium, design: .rounded))
                    Text("Курсор заметен. Содержимое открыто.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Button("Проверить эффекты", action: preview)
                        .buttonStyle(.link).font(.system(size: 11)).padding(.top, 4)
                }
                Spacer(minLength: 10)
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(.background.opacity(0.7))
                        .frame(width: 126, height: 76)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 6) {
                                Capsule().fill(.primary.opacity(0.15)).frame(width: 55, height: 4)
                                Capsule().fill(.primary.opacity(0.09)).frame(width: 83, height: 4)
                                Capsule().fill(.primary.opacity(0.09)).frame(width: 71, height: 4)
                            }.padding(14)
                        }
                    if preferences.ringEnabled {
                        Circle().strokeBorder(.primary.opacity(0.12), lineWidth: preferences.lineWidth + 1.5)
                            .frame(width: preferences.radius * 2, height: preferences.radius * 2)
                        Circle().strokeBorder(preferences.tint.color.opacity(preferences.opacity), lineWidth: preferences.lineWidth)
                            .frame(width: preferences.radius * 2, height: preferences.radius * 2)
                    }
                    Image(systemName: "cursorarrow").font(.system(size: 23, weight: .medium))
                        .foregroundStyle(.primary).shadow(color: .white.opacity(0.9), radius: 1)
                        .offset(x: 7, y: 12)
                }
                .frame(width: 150, height: 112)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .opacity(preferences.running ? 1 : 0.45)
        }
        .frame(height: 164)
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.06), lineWidth: 0.75))
    }
}
