import Foundation

actor ContainerService {
    private let cliPath: String
    
    init(cliPath: String = "/usr/local/bin/container") {
        self.cliPath = cliPath
    }
    
    func listContainers(showAll: Bool = false) async throws -> [ContainerInfo] {
        do {
            var args = ["list", "--format", "json"]
            if showAll {
                args.append("--all")
            }
            let output = try await execute(arguments: args)
            return try parseContainerListJSON(output)
        } catch {
            throw AppError(message: "Failed to list containers", underlyingError: error)
        }
    }
    
    func inspectContainer(id: String) async throws -> String {
        do {
            return try await execute(arguments: ["inspect", id])
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
            _ = try await execute(arguments: ["stop", id])
        } catch {
            throw AppError(message: "Failed to stop container '\(id)'", underlyingError: error)
        }
    }
    
    func killContainer(id: String) async throws {
        do {
            _ = try await execute(arguments: ["kill", id])
        } catch {
            throw AppError(message: "Failed to kill container '\(id)'", underlyingError: error)
        }
    }
    
    func removeContainer(id: String) async throws {
        do {
            _ = try await execute(arguments: ["delete", id])
        } catch {
            throw AppError(message: "Failed to remove container '\(id)'", underlyingError: error)
        }
    }
    
    func streamLogs(containerId: String, follow: Bool = false) async throws -> AsyncStream<String> {
        var args = ["logs", containerId]
        if follow {
            args.append("--follow")
        }
        return try await executeStreaming(arguments: args)
    }
    
    func getSystemStatus() async throws -> String {
        return try await execute(arguments: ["system", "status"])
    }
    
    func listVolumes() async throws -> [VolumeInfo] {
        let output = try await execute(arguments: ["volume", "list", "--format", "json"])
        return try parseVolumeListJSON(output)
    }
    
    func inspectVolume(name: String) async throws -> String {
        return try await execute(arguments: ["volume", "inspect", name])
    }
    
    func listNetworks() async throws -> [NetworkInfo] {
        let output = try await execute(arguments: ["network", "list", "--format", "json"])
        return try parseNetworkListJSON(output)
    }
    
    func inspectNetwork(name: String) async throws -> String {
        return try await execute(arguments: ["network", "inspect", name])
    }
    
    func streamSystemLogs(follow: Bool = false) async throws -> AsyncStream<String> {
        var args = ["system", "logs"]
        if follow {
            args.append("--follow")
        }
        return try await executeStreaming(arguments: args)
    }
    
    private func execute(arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            
            guard FileManager.default.fileExists(atPath: cliPath) else {
                continuation.resume(throwing: AppError(message: "Container CLI not found at \(cliPath)"))
                return
            }
            
            task.executableURL = URL(fileURLWithPath: cliPath)
            task.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            task.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus != 0 {
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: AppError(message: errorMessage))
                    return
                }
                
                guard let output = String(data: outputData, encoding: .utf8) else {
                    continuation.resume(throwing: AppError(message: "Invalid output encoding"))
                    return
                }
                
                continuation.resume(returning: output)
            }
            
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: AppError(message: "Failed to execute container command", underlyingError: error))
            }
        }
    }
    
    private func executeStreaming(arguments: [String]) async throws -> AsyncStream<String> {
        guard FileManager.default.fileExists(atPath: cliPath) else {
            throw AppError(message: "Container CLI not found at \(cliPath)")
        }
        
        return AsyncStream { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: cliPath)
            task.arguments = arguments
            
            let pipe = Pipe()
            task.standardOutput = pipe
            let handle = pipe.fileHandleForReading
            
            task.terminationHandler = { _ in
                // Read any remaining data when process terminates
                let data = handle.availableData
                if !data.isEmpty, let line = String(data: data, encoding: .utf8) {
                    line.components(separatedBy: .newlines)
                        .filter { !$0.isEmpty }
                        .forEach { continuation.yield($0) }
                }
                continuation.finish()
            }
            
            NotificationCenter.default.addObserver(
                forName: .NSFileHandleDataAvailable,
                object: handle,
                queue: nil
            ) { _ in
                let data = handle.availableData
                if !data.isEmpty, let line = String(data: data, encoding: .utf8) {
                    line.components(separatedBy: .newlines)
                        .filter { !$0.isEmpty }
                        .forEach { continuation.yield($0) }
                    handle.waitForDataInBackgroundAndNotify()
                }
            }
            
            handle.waitForDataInBackgroundAndNotify()
            
            do {
                try task.run()
            } catch {
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                task.terminate()
            }
        }
    }
    
    private func parseContainerListJSON(_ output: String) throws -> [ContainerInfo] {
        guard let data = output.data(using: .utf8) else {
            throw AppError(message: "Invalid output encoding")
        }
        
        struct Network: Codable {
            let address: String?
        }
        
        struct ImageRef: Codable {
            let reference: String
        }
        
        struct Configuration: Codable {
            let id: String
            let hostname: String?
            let image: ImageRef
        }
        
        struct ContainerJSON: Codable {
            let configuration: Configuration
            let networks: [Network]?
            let status: String
        }
        
        let containers = try JSONDecoder().decode([ContainerJSON].self, from: data)
        
        return containers.map { json in
            let state: ContainerState
            let status = json.status.lowercased()
            if status.contains("running") {
                state = .running
            } else if status.contains("exited") {
                state = .exited
            } else if status.contains("paused") {
                state = .paused
            } else if status.contains("created") {
                state = .created
            } else {
                state = .stopped
            }
            
            let ipAddress = json.networks?.first?.address?.components(separatedBy: "/").first
            
            return ContainerInfo(
                id: json.configuration.id,
                name: json.configuration.hostname ?? json.configuration.id,
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
            let mountpoint: String?
            
            enum CodingKeys: String, CodingKey {
                case name = "Name"
                case driver = "Driver"
                case mountpoint = "Mountpoint"
            }
        }
        
        let volumes = try JSONDecoder().decode([VolumeJSON].self, from: data)
        
        return volumes.map { json in
            VolumeInfo(
                id: json.name,
                name: json.name,
                driver: json.driver,
                mountpoint: json.mountpoint
            )
        }
    }
    
    private func parseNetworkListJSON(_ output: String) throws -> [NetworkInfo] {
        guard let data = output.data(using: .utf8) else {
            throw AppError(message: "Invalid output encoding")
        }
        
        struct NetworkJSON: Codable {
            let name: String
            let subnet: String?
            let gateway: String?
            
            enum CodingKeys: String, CodingKey {
                case name = "Name"
                case subnet = "Subnet"
                case gateway = "Gateway"
            }
        }
        
        let networks = try JSONDecoder().decode([NetworkJSON].self, from: data)
        
        return networks.map { json in
            NetworkInfo(
                id: json.name,
                name: json.name,
                subnet: json.subnet,
                gateway: json.gateway
            )
        }
    }
}
