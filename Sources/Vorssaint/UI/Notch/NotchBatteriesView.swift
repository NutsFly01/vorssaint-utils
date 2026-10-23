// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Mac's battery and every accessory reporting one, AirPods to mice, each
/// on a card of its own laid out like the System page's. Earbuds show each
/// side and their case apart.
struct NotchBatteriesView: View {
    let size: CGSize
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Part: Identifiable {
        let position: PeripheralBatteryPart.Position
        let symbol: String
        let percent: Int
        var id: String { position.rawValue }
    }

    private struct Card: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let percent: Int?
        var parts: [Part] = []
        /// A Mac on power is not running out, however low.
        var charging = false
    }

    private var cards: [Card] {
        let snapshot = monitor.snapshot
        var cards: [Card] = []
        // The same condition the island sizes the page with, so the card
        // waits for its first reading instead of resizing the page.
        if PowerSampler.hasInternalBattery {
            let power = snapshot.power
            cards.append(Card(id: "mac", title: "Mac",
                              symbol: power?.externalConnected == true ? "bolt.fill" : "laptopcomputer",
                              percent: power?.chargePercent, charging: power?.externalConnected == true))
        }
        for device in NotchAccessorySupport.pageDevices(snapshot.peripheralBatteries) {
            let glyphs = NotchAccessorySupport.glyphs(for: device)
            cards.append(Card(id: device.id, title: device.name, symbol: glyphs.device, percent: device.percent,
                              parts: device.parts.map {
                                  Part(position: $0.position, symbol: glyphs.symbol(for: $0.position), percent: $0.percent)
                              }))
        }
        return cards
    }

    var body: some View {
        content
            .onAppear { SystemMonitor.shared.refreshPeripheralBatteries() }
    }

    @ViewBuilder private var content: some View {
        let cards = cards
        if cards.isEmpty {
            NotchEmptyView(symbol: NotchModule.batteries.symbol, message: l10n.s.peripheralBatteryNoDevices)
        } else {
            // The System page's grid, so both pages size alike in the island.
            let inset = NotchLayout.systemHoverInset(width: size.width)
            let rows = NotchLayout.systemRowRanges(count: cards.count, width: size.width - inset * 2)
            let height = NotchLayout.railHeight(rows: rows.count, rowHeight: NotchLayout.systemCardHeight,
                                               spacing: NotchLayout.rowSpacing) + inset * 2
            Group {
                if height > size.height {
                    ScrollView { grid(cards: cards, rows: rows).padding(inset) }
                } else {
                    grid(cards: cards, rows: rows).padding(inset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func grid(cards: [Card], rows: [Range<Int>]) -> some View {
        VStack(spacing: NotchLayout.rowSpacing) {
            ForEach(rows, id: \.lowerBound) { row in
                HStack(spacing: NotchLayout.rowSpacing) {
                    ForEach(Array(cards[row])) { card in
                        cardView(card).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func cardView(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(card.title, systemImage: card.symbol)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary).lineLimit(1)
            if card.parts.isEmpty {
                let value = card.percent.map { "\($0)%" }
                Text(value ?? "…")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .monospacedDigit().contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.75)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: value)
                NotchMeter(value: Double(card.percent ?? 0) / 100, tint: card.charging ? .white : tint(card.percent))
            } else {
                // Narrow cards drop the percent signs before shrinking the digits.
                ViewThatFits(in: .horizontal) {
                    partsRow(card.parts, percentSign: true)
                    partsRow(card.parts, percentSign: false)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: NotchLayout.systemCardHeight)
        .modifier(NotchControlSurface(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.title)
        .accessibilityValue(card.parts.isEmpty
            ? card.percent.map { "\($0)%" } ?? ""
            : card.parts.map { title($0.position) + " \($0.percent)%" }.joined(separator: ", "))
    }

    private func partsRow(_ parts: [Part], percentSign: Bool) -> some View {
        HStack(spacing: 10) {
            ForEach(parts) { part in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 3) {
                        Image(systemName: part.symbol)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(percentSign ? "\(part.percent)%" : "\(part.percent)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .monospacedDigit().contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.75)
                            .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: part.percent)
                    }
                    .fixedSize()
                    NotchMeter(value: Double(part.percent) / 100, height: 4, tint: tint(part.percent))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(title(part.position))
            }
        }
    }

    /// Low enough that the meter says so without the number being read.
    private func tint(_ percent: Int?) -> Color {
        (percent ?? 100) <= NotchAccessorySupport.lowThreshold ? .orange : .white
    }

    private func title(_ position: PeripheralBatteryPart.Position) -> String {
        let text = FeatureStrings.notch(l10n.language)
        switch position {
        case .left: return text.batteryLeft
        case .right: return text.batteryRight
        case .chargingCase: return text.batteryCase
        }
    }
}
