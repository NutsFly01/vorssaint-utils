// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum NotchAccessorySupport {
    static let lowThreshold = 20
    static let recoveryThreshold = 25
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        NotchSupport.isEnabled(in: defaults) && AppFeature.notchAccessories.isAvailable(in: defaults)
            && AppFeature.monitorPower.isAvailable(in: defaults)
            && defaults.bool(forKey: DefaultsKey.notchAccessoriesEnabled)
    }

    static func symbol(for kind: PeripheralBatteryKind, name: String) -> String {
        let kind = kind == .device
            ? PeripheralBatterySupport.kind(product: name, primaryUsagePage: nil, primaryUsage: nil, usagePairs: [])
            : kind
        switch kind {
        case .audio: return AppleAudioModel(name: name)?.glyphs.device ?? "headphones"
        case .keyboard: return "keyboard"
        case .mouse: return name.lowercased().contains("magic mouse") ? "magicmouse" : "computermouse"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .device: return "dot.radiowaves.left.and.right"
        }
    }

    /// Phones, tablets, computers and network access points are not
    /// accessories, and their Bluetooth links come and go without anyone
    /// reaching for them. Every other class announces a connection,
    /// including a device that declares no class at all.
    static func announcesConnection(majorClass: UInt32) -> Bool {
        !(0x01...0x03).contains(majorClass)
    }

    /// A name says what an accessory is only until someone renames it. The
    /// Bluetooth class of device it announces still does, from a speaker or
    /// a car down to the trackpad that sets a pointer's digitizer bits.
    /// Major and minor classes as the Bluetooth assigned numbers define them.
    static func symbol(name: String, majorClass: UInt32, minorClass: UInt32) -> String {
        let named = PeripheralBatterySupport.kind(product: name, primaryUsagePage: nil, primaryUsage: nil, usagePairs: [])
        guard named == .device else { return symbol(for: named, name: name) }
        switch (majorClass, minorClass) {
        case (0x04, 0x04): return "mic"
        case (0x04, 0x05), (0x04, 0x07), (0x04, 0x0A): return "hifispeaker"
        case (0x04, 0x08): return "car"
        case (0x04, 0x0E), (0x04, 0x0F): return "tv"
        case (0x04, 0x12): return "gamecontroller"
        case (0x04, 0x01), (0x04, 0x02), (0x04, 0x06): return symbol(for: .audio, name: name)
        case (0x05, let minor) where [0x01, 0x02].contains(minor & 0x0F): return "gamecontroller"
        case (0x05, let minor) where minor & 0x0F == 0x03: return "av.remote"
        case (0x05, let minor) where minor & 0x30 == 0x20:
            return minor & 0x0F == 0x05 ? symbol(for: .trackpad, name: name) : symbol(for: .mouse, name: name)
        case (0x05, let minor) where minor & 0x10 != 0: return symbol(for: .keyboard, name: name)
        case (0x06, let minor) where minor & 0x20 != 0: return "printer"
        case (0x07, 0x01): return "applewatch"
        case (0x07, 0x05): return "eyeglasses"
        case (0x08, _): return "gamecontroller"
        default: return symbol(for: .device, name: name)
        }
    }

    /// The Batteries page lists every accessory with a reading it can trust,
    /// lowest first as the panel lists them.
    static func pageDevices(_ devices: [PeripheralBatteryDevice]) -> [PeripheralBatteryDevice] {
        PeripheralBatterySupport.sorted(devices.filter { (0...100).contains($0.percent) })
    }

    /// The Mac's own battery leads the page on a laptop.
    static func pageCardCount(hasBattery: Bool, devices: [PeripheralBatteryDevice]) -> Int {
        (hasBattery ? 1 : 0) + pageDevices(devices).count
    }

    /// A card's symbols: the model's own when the product ID or the name
    /// says which it is, else the accessory's kind with generic sides.
    static func glyphs(for device: PeripheralBatteryDevice) -> NotchAccessoryGlyphs {
        if let model = AppleAudioModel(productID: device.productID) ?? AppleAudioModel(name: device.name) {
            return model.glyphs
        }
        return NotchAccessoryGlyphs(device: symbol(for: device.kind, name: device.name))
    }

    /// Newer models have symbols only recent macOS versions draw; the first
    /// candidate this one has is used, else the last.
    static func drawable(_ candidates: [String]) -> String {
        candidates.first { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil } ?? candidates.last ?? ""
    }

    static func identity(_ device: PeripheralBatteryDevice) -> String {
        // The existing sampler coalesces the same physical accessory by name
        // when its reading moves between HID, system metadata and Bluetooth.
        device.kind.rawValue + ":" + device.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// The symbols a Batteries card draws: the device, then each side and the case.
struct NotchAccessoryGlyphs: Equatable {
    var device: String
    var left = "airpod.left"
    var right = "airpod.right"
    var chargingCase = "earbuds.case"

    func symbol(for position: PeripheralBatteryPart.Position) -> String {
        switch position {
        case .left: return left
        case .right: return right
        case .chargingCase: return chargingCase
        }
    }
}

/// Apple's and Beats' earbuds and headphones: by product ID first, since a
/// name changes when someone renames the accessory, then by the name it came
/// with. Each model draws its own device, sides and case.
enum AppleAudioModel: CaseIterable {
    case airPods, airPods3, airPods4, airPodsPro, airPodsMax
    case beatsHeadphones, beatsEarphones, powerbeats, powerbeatsPro, studioBuds, studioBudsPlus, fitPro, soloBuds, pill

    /// Only the IDs known for certain; other models are still recognized by name.
    init?(productID: Int?) {
        switch productID {
        case 0x2002, 0x200F: self = .airPods
        case 0x2013: self = .airPods3
        case 0x200E, 0x2014, 0x2024: self = .airPodsPro
        case 0x200A: self = .airPodsMax
        case 0x2006, 0x2009, 0x200C, 0x2017: self = .beatsHeadphones
        case 0x2005, 0x2010: self = .beatsEarphones
        case 0x2003, 0x200D: self = .powerbeats
        case 0x200B: self = .powerbeatsPro
        case 0x2011: self = .studioBuds
        case 0x2016: self = .studioBudsPlus
        case 0x2012: self = .fitPro
        default: return nil
        }
    }

    /// Longer names first, so "AirPods Pro" is not taken for AirPods.
    init?(name: String) {
        let name = name.lowercased()
        func has(_ words: String...) -> Bool { words.contains { name.contains($0) } }
        if has("airpods max") { self = .airPodsMax }
        else if has("airpods pro") { self = .airPodsPro }
        else if has("airpods 4", "airpods (4") { self = .airPods4 }
        else if has("airpods 3", "airpods (3") { self = .airPods3 }
        else if has("airpods") { self = .airPods }
        else if has("powerbeats pro") { self = .powerbeatsPro }
        else if has("powerbeats") { self = .powerbeats }
        else if has("studio buds+", "studio buds +", "studio buds plus") { self = .studioBudsPlus }
        else if has("studio buds") { self = .studioBuds }
        else if has("beats fit pro") { self = .fitPro }
        else if has("solo buds") { self = .soloBuds }
        else if has("beats pill") { self = .pill }
        else if has("beatsx", "beats x", "beats flex") { self = .beatsEarphones }
        else if has("beats solo", "beats studio") { self = .beatsHeadphones }
        else { return nil }
    }

    var glyphs: NotchAccessoryGlyphs {
        let drawable = NotchAccessorySupport.drawable
        switch self {
        case .airPods: return NotchAccessoryGlyphs(device: "airpods", chargingCase: "airpods.chargingcase")
        case .airPods3:
            return NotchAccessoryGlyphs(device: "airpods.gen3", left: "airpod.gen3.left", right: "airpod.gen3.right",
                                        chargingCase: "airpods.gen3.chargingcase.wireless")
        case .airPods4:
            return NotchAccessoryGlyphs(device: drawable(["airpods.gen4", "airpods.gen3"]),
                                        left: drawable(["airpods.gen4.left", "airpod.gen3.left"]),
                                        right: drawable(["airpods.gen4.right", "airpod.gen3.right"]),
                                        chargingCase: drawable(["airpods.gen4.chargingcase.wireless", "airpods.gen3.chargingcase.wireless"]))
        case .airPodsPro:
            return NotchAccessoryGlyphs(device: "airpodspro", left: "airpodpro.left", right: "airpodpro.right",
                                        chargingCase: "airpodspro.chargingcase.wireless")
        case .airPodsMax: return NotchAccessoryGlyphs(device: "airpodsmax")
        case .beatsHeadphones: return NotchAccessoryGlyphs(device: "beats.headphones")
        case .beatsEarphones: return NotchAccessoryGlyphs(device: "beats.earphones")
        case .powerbeats:
            return NotchAccessoryGlyphs(device: "beats.powerbeats", left: "beats.powerbeats.left", right: "beats.powerbeats.right")
        case .powerbeatsPro:
            return NotchAccessoryGlyphs(device: "beats.powerbeatspro", left: "beats.powerbeatspro.left",
                                        right: "beats.powerbeatspro.right", chargingCase: "beats.powerbeatspro.chargingcase")
        case .studioBuds:
            return NotchAccessoryGlyphs(device: "beats.studiobuds", left: "beats.studiobud.left",
                                        right: "beats.studiobud.right", chargingCase: "beats.studiobuds.chargingcase")
        case .studioBudsPlus:
            return NotchAccessoryGlyphs(device: "beats.studiobudsplus", left: "beats.studiobudsplus.left",
                                        right: "beats.studiobudsplus.right", chargingCase: "beats.studiobudsplus.chargingcase")
        case .fitPro:
            return NotchAccessoryGlyphs(device: "beats.fitpro", left: "beats.fitpro.left", right: "beats.fitpro.right",
                                        chargingCase: "beats.fitpro.chargingcase")
        case .soloBuds:
            return NotchAccessoryGlyphs(device: drawable(["beats.solobuds", "earbuds"]),
                                        left: drawable(["beats.solobuds.left", "airpod.left"]),
                                        right: drawable(["beats.solobuds.right", "airpod.right"]),
                                        chargingCase: drawable(["beats.solobuds.chargingcase", "earbuds.case"]))
        case .pill: return NotchAccessoryGlyphs(device: drawable(["beats.pill", "hifispeaker"]))
        }
    }
}

/// Missing telemetry is not a disconnection or a recharge. A low episode
/// survives both, until an actual reading reaches the recovery threshold.
struct NotchAccessoryBatteryState {
    private var lowEpisodes: [String: Bool] = [:]
    private var insertionOrder: [String] = []
    private var lastObservation: [String: TimeInterval] = [:]

    func isFresh(_ device: PeripheralBatteryDevice, in sample: PeripheralBatterySample,
                 observedAfter activation: TimeInterval) -> Bool {
        let key = NotchAccessorySupport.identity(device)
        guard (0...100).contains(device.percent), let observedAt = sample.observedAt[device.id],
              observedAt.isFinite else { return false }
        return observedAt >= activation && observedAt > (lastObservation[key] ?? -.greatestFiniteMagnitude)
    }

    mutating func consume(_ sample: PeripheralBatterySample, observedAfter activation: TimeInterval) -> [PeripheralBatteryDevice] {
        let fresh = sample.devices.filter { isFresh($0, in: sample, observedAfter: activation) }
        for device in fresh {
            lastObservation[NotchAccessorySupport.identity(device)] = sample.observedAt[device.id]
        }
        return consume(fresh)
    }

    mutating func consume(_ devices: [PeripheralBatteryDevice]) -> [PeripheralBatteryDevice] {
        var alerts: [PeripheralBatteryDevice] = []
        for device in devices where (0...100).contains(device.percent) {
            let key = NotchAccessorySupport.identity(device)
            guard let low = lowEpisodes[key] else {
                lowEpisodes[key] = device.percent <= NotchAccessorySupport.lowThreshold
                insertionOrder.append(key)
                if insertionOrder.count > 128 {
                    let oldest = insertionOrder.removeFirst()
                    lowEpisodes.removeValue(forKey: oldest)
                    lastObservation.removeValue(forKey: oldest)
                }
                continue
            }
            if device.percent >= NotchAccessorySupport.recoveryThreshold {
                lowEpisodes[key] = false
            } else if device.percent <= NotchAccessorySupport.lowThreshold, !low {
                lowEpisodes[key] = true
                alerts.append(device)
            }
        }
        return PeripheralBatterySupport.sorted(alerts)
    }
}

struct NotchAccessoryConnectionState {
    private var connectedIDs: Set<String> = []
    mutating func establishBaseline(_ ids: Set<String>) { connectedIDs = ids }
    mutating func connected(_ id: String) -> Bool {
        guard !id.isEmpty else { return false }
        return connectedIDs.insert(id).inserted
    }
    mutating func disconnected(_ id: String) { connectedIDs.remove(id) }
}
