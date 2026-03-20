import Foundation

struct ContainerService {
    private let cli = CLIExecutor()
    
    func listContainers(showAll: Bool = false) async throws -> [ContainerInfo] {
        do {
            var args = ["list", "--format", "json"]
            if showAll { args.append("--all") }
            let output = try await cli.execute(arguments: args)
            return try parseContainerListJSON(output)
        } catch {
            throw AppError(message: "Failed to list containers", underlyingError: error)
        }
    }
    
    func inspectContainer(id: String) async throws -> String {
        do {
            return try await cli.execute(arguments: ["inspect", id])
        } catch {
            throw AppError(message: "Failed to inspect container '\(id)'", underlyingError: error)
        }
    }
    
    func getContainer(id: String) async throws -> ContainerInfo? {
        let containers = try await listContainers()
        return containers.first { $0.id == id || $0.id.hasPrefix(id) }
    }
    
    func stopContainer(id: String) async throws {
        do {
            _ = try await cli.execute(arguments: ["stop", id])
        } catch {
            throw AppError(message: "Failed to stop container '\(id)'", underlyingError: error)
        }
    }
    
    func startContainer(id: String) async throws {
        do {
            _ = try await cli.execute(arguments: ["start", id])
        } catch {
            throw AppError(message: "Failed to start container '\(id)'", underlyingError: error)
        }
    }
    
    func killContainer(id: String) async throws {
        do {
            _ = try await cli.execute(arguments: ["kill", id])
        } catch {
            throw AppError(message: "Failed to kill container '\(id)'", underlyingError: error)
        }
    }
    
    func removeContainer(id: String) async throws {
        do {
            _ = try await cli.execute(arguments: ["delete", id])
        } catch {
            throw AppError(message: "Failed to remove container '\(id)'", underlyingError: error)
        }
    }
    
    func streamLogs(containerId: String, follow: Bool = false) throws -> AsyncStream<String> {
        var args = ["logs", containerId]
        if follow { args.append("--follow") }
        return try cli.executeStreaming(arguments: args)
    }
    
    func getSystemStatus() async throws -> String {
        return try await cli.execute(arguments: ["system", "status"])
    }
    
    func listVolumes() async throws -> [VolumeInfo] {
        let output = try await cli.execute(arguments: ["volume", "list", "--format", "json"])
        return try parseVolumeListJSON(output)
    }
    
    func inspectVolume(name: String) async throws -> String {
        return try await cli.execute(arguments: ["volume", "inspect", name])
    }
    
    func listNetworks() async throws -> [NetworkInfo] {
        let output = try await cli.execute(arguments: ["network", "list", "--format", "json"])
        return try parseNetworkListJSON(output)
    }
    
    func inspectNetwork(name: String) async throws -> String {
        return try await cli.execute(arguments: ["network", "inspect", name])
    }
    
    func streamSystemLogs(follow: Bool = false) throws -> AsyncStream<String> {
        var args = ["system", "logs"]
        if follow { args.append("--follow") }
        return try cli.executeStreaming(arguments: args)
    }
    
    func getContainerStats() async throws -> [ContainerStats] {
        do {
            let output = try await cli.execute(arguments: ["stats", "--format", "json", "--no-stream"])
            return try parseContainerStatsJSON(output)
        } catch {
            throw AppError(message: "Failed to get container stats", underlyingError: error)
        }
    }
    
    func pruneContainers() async throws -> String {
        do {
            return try await cli.execute(arguments: ["prune"])
        } catch {
            throw AppError(message: "Failed to prune containers", underlyingError: error)
        }
    }
    
    func pruneVolumes() async throws -> String {
        do {
            return try await cli.execute(arguments: ["volume", "prune"])
        } catch {
            throw AppError(message: "Failed to prune volumes", underlyingError: error)
        }
    }
    
    func pruneNetworks() async throws -> String {
        do {
            return try await cli.execute(arguments: ["network", "prune"])
        } catch {
            throw AppError(message: "Failed to prune networks", underlyingError: error)
        }
    }
    
    // MARK: - JSON Parsing
    
    private func parseContainerListJSON(_ output: String) throws -> [ContainerInfo] {
        guard let data = output.data(using: .utf8) else {
            throw AppError(message: "Invalid output encoding")
        }
        
        struct Attachment: Codable {
            let ipv4Address: String?
        }
        
        struct ImageRef: Codable {
            let reference: String
        }
        
        struct Configuration: Codable {
            let id: String
            let image: ImageRef
        }
        
        struct ContainerJSON: Codable {
            let configuration: Configuration
            let networks: [Attachment]?
            let status: String
        }
        
        let containers = try JSONDecoder().decode([ContainerJSON].self, from: data)
        
        return containers.map { json in
            let state = ContainerState(rawValue: json.status) ?? .unknown
            let ipAddress = json.networks?.first?.ipv4Address?
                .components(separatedBy: "/").first
            
            return ContainerInfo(
                id: json.configuration.id,
                name: json.configuration.id,
                image: json.configuration.image.reference,
                state: state,
                ipAddress: ipAddress,
                createdAt: nil,
                command: nil
            )
        }
    }
    
    private func parseVolumeListJSON(_ output: String) throws -> [VolumeInfo] {
        guard let data = output.data(using: .utf8) else {
            throw AppError(message: "Invalid output encoding")
        }
        
        struct VolumeJSON: Codable {
            let name: String
            let driver: String
            let format: String?
            let source: String?
            let createdAt: String?
            let sizeInBytes: UInt64?
        }
        
        let volumes = try JSONDecoder().decode([VolumeJSON].self, from: data)
        
        return volumes.map { json in
            let date: Date? = json.createdAt.flatMap {
                ISO8601DateFormatter().date(from: $0)
            }
            return VolumeInfo(
                name: json.name,
                driver: json.driver,
                format: json.format,
                source: json.source,
                createdAt: date,
                sizeInBytes: json.sizeInBytes
            )
        }
    }
    
    private func parseNetworkListJSON(_ output: String) throws -> [NetworkInfo] {
        guard let data = output.data(using: .utf8) else {
            throw AppError(message: "Invalid output encoding")
        }
        
        struct NetworkJSON: Codable {
            let id: String
            let status: Status?
            
            struct Status: Codable {
                let ipv4Subnet: String?
                let ipv6Subnet: String?
            }
        }
        
        let networks = try JSONDecoder().decode([NetworkJSON].self, from: data)
        
        return networks.map { json in
            NetworkInfo(
                name: json.id,
                subnet: json.status?.ipv4Subnet,
                subnetV6: json.status?.ipv6Subnet
            )
        }
    }
    
    private func parseContainerStatsJSON(_ output: String) throws -> [ContainerStats] {
        guard let data = output.data(using: .utf8) else {
            throw AppError(message: "Invalid output encoding")
        }
        
        struct StatsJSON: Codable {
            let container_id: String?
            let id: String?
            let name: String?
            let cpu_percent: Double?
            let cpuPercentage: Double?
            let mem_usage: String?
            let memoryUsage: String?
            let mem_limit: String?
            let memoryLimit: String?
            let net_io: String?
            let networkIO: String?
            let block_io: String?
            let blockIO: String?
            let pids: Int?
            
            enum CodingKeys: String, CodingKey {
                case container_id = "container_id"
                case id
                case name
                case cpu_percent = "cpu_percent"
                case cpuPercentage = "cpuPercentage"
                case mem_usage = "mem_usage"
                case memoryUsage = "memoryUsage"
                case mem_limit = "mem_limit"
                case memoryLimit = "memoryLimit"
                case net_io = "net_io"
                case networkIO = "networkIO"
                case block_io = "block_io"
                case blockIO = "blockIO"
                case pids
            }
        }
        
        let items = try JSONDecoder().decode([StatsJSON].self, from: data)
        
        return items.map { json in
            let containerId = json.container_id ?? json.id ?? json.name ?? "unknown"
            return ContainerStats(
                id: containerId,
                name: json.name ?? containerId,
                cpuPercentage: json.cpu_percent ?? json.cpuPercentage ?? 0.0,
                memoryUsage: json.mem_usage ?? json.memoryUsage ?? "-",
                memoryLimit: json.mem_limit ?? json.memoryLimit ?? "-",
                networkIO: json.net_io ?? json.networkIO ?? "-",
                blockIO: json.block_io ?? json.blockIO ?? "-",
                pids: json.pids ?? 0
            )
        }
    }
}
