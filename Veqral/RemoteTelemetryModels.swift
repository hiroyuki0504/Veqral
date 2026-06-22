import Foundation

struct RemoteHostTelemetry: Codable, Equatable, Sendable {
    var checkedAt: Date
    var cpu: RemoteHostTelemetryCPU
    var memory: RemoteHostTelemetryMemory
    var disk: RemoteHostTelemetryDisk
    var thermal: RemoteHostTelemetryThermal
    var uptime: RemoteHostTelemetryUptime
    var power: RemoteHostTelemetryPower
    var network: RemoteHostTelemetryNetwork
    var topProcesses: [RemoteHostTelemetryProcess]
}

struct RemoteHostTelemetryCPU: Codable, Equatable, Sendable {
    var totalPercent: Double?
    var perCorePercent: [Double]
    var loadAverage: [Double]
}

struct RemoteHostTelemetryMemory: Codable, Equatable, Sendable {
    var totalBytes: UInt64?
    var usedBytes: UInt64?
    var freeBytes: UInt64?
    var pressure: String
}

struct RemoteHostTelemetryDisk: Codable, Equatable, Sendable {
    var mountPoint: String
    var totalBytes: UInt64?
    var freeBytes: UInt64?
    var usedPercent: Double?
    var smartStatus: String?
}

struct RemoteHostTelemetryThermal: Codable, Equatable, Sendable {
    var state: String
    var rawTemperatureC: Double?
    var fanRPM: Double?
}

struct RemoteHostTelemetryUptime: Codable, Equatable, Sendable {
    var seconds: TimeInterval
    var osVersion: String
    var hostName: String
    var machineModel: String
}

struct RemoteHostTelemetryPower: Codable, Equatable, Sendable {
    var isBatteryAvailable: Bool
    var batteryPercent: Double?
    var isCharging: Bool?
    var isACPowered: Bool?
}

struct RemoteHostTelemetryNetwork: Codable, Equatable, Sendable {
    var tailscaleIP: String?
    var interfaceName: String?
    var rxBytesPerSecond: Double?
    var txBytesPerSecond: Double?
}

struct RemoteHostTelemetryProcess: Codable, Identifiable, Equatable, Sendable {
    var pid: Int32
    var name: String
    var cpuPercent: Double?
    var memoryMB: Double?

    var id: Int32 { pid }
}
