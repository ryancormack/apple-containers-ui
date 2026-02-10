import Foundation

actor ImageService {
    private let cliPath: String
    
    init(cliPath: String = "/usr/local/bin/container") {
        self.cliPath = cliPath
    }
    
    func listImages() async throws -> [ImageInfo] {
        do {
            let output = try await execute(arguments: ["image", "list", "--format", "json"])
            return try parseImageListJSON(output)
        } catch {
            throw AppError(message: "Failed to list images", underlyingError: error)
        }
    }
    
    func inspectImage(reference: String) async throws -> String {
        do {
            return try await execute(arguments: ["image", "inspect", reference])
        } catch {
            throw AppError(message: "Failed to inspect image '\(reference)'", underlyingError: error)
        }
    }
    
    func getImage(reference: String) async throws -> ImageInfo? {
        let images = try await listImages()
        return images.first { $0.displayName == reference }
    }
    
    func pullImage(reference: String, onProgress: @escaping (Double) -> Void) async throws {
        do {
            _ = try await execute(arguments: ["image", "pull", reference])
        } catch {
            throw AppError(message: "Failed to pull image '\(reference)'", underlyingError: error)
        }
    }
    
    func removeImage(reference: String) async throws {
        do {
            _ = try await execute(arguments: ["image", "remove", reference])
        } catch {
            throw AppError(message: "Failed to remove image '\(reference)'", underlyingError: error)
        }
    }
    
    func tagImage(source: String, target: String) async throws {
        do {
            _ = try await execute(arguments: ["image", "tag", source, target])
        } catch {
            throw AppError(message: "Failed to tag image", underlyingError: error)
        }
    }
    
    func runImage(reference: String, name: String?) async throws {
        var args = ["run", "-d"]
        if let name = name {
            args.append(contentsOf: ["--name", name])
        }
        args.append(reference)
        
        do {
            _ = try await execute(arguments: args)
        } catch {
            throw AppError(message: "Failed to run image", underlyingError: error)
        }
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
    
    private func parseImageListJSON(_ output: String) throws -> [ImageInfo] {
        guard let data = output.data(using: .utf8) else {
            throw AppError(message: "Invalid output encoding")
        }
        
        struct Descriptor: Codable {
            let digest: String
            let size: Int64
        }
        
        struct ImageJSON: Codable {
            let descriptor: Descriptor
            let reference: String
        }
        
        let images = try JSONDecoder().decode([ImageJSON].self, from: data)
        
        return images.map { json in
            let parts = json.reference.split(separator: ":")
            let name = parts.dropLast().joined(separator: ":")
            let tag = parts.last.map(String.init) ?? "latest"
            
            return ImageInfo(
                id: json.reference,
                name: name,
                tag: tag,
                digest: json.descriptor.digest,
                size: json.descriptor.size,
                createdAt: nil
            )
        }
    }
}
