import Foundation

struct ImageService {
    private let cli = CLIExecutor()
    
    func listImages() async throws -> [ImageInfo] {
        do {
            let output = try await cli.execute(arguments: ["image", "list", "--format", "json"])
            var images = try parseImageListJSON(output)
            
            // Fetch real sizes from inspect (arm64 variant) in parallel
            await withTaskGroup(of: (Int, Int64?).self) { group in
                for (index, image) in images.enumerated() {
                    group.addTask {
                        let size = try? await self.fetchArm64Size(reference: image.id)
                        return (index, size)
                    }
                }
                for await (index, size) in group {
                    images[index] = images[index].withSize(size)
                }
            }
            
            return images
        } catch {
            throw AppError(message: "Failed to list images", underlyingError: error)
        }
    }
    
    private func fetchArm64Size(reference: String) async throws -> Int64? {
        let output = try await cli.execute(arguments: ["image", "inspect", reference])
        guard let data = output.data(using: .utf8) else { return nil }
        
        struct Platform: Codable { let architecture: String?; let os: String? }
        struct Variant: Codable { let size: Int64; let platform: Platform? }
        struct InspectResult: Codable { let variants: [Variant]? }
        
        let results = try JSONDecoder().decode([InspectResult].self, from: data)
        return results.first?.variants?
            .first { $0.platform?.architecture == "arm64" && $0.platform?.os == "linux" }?
            .size
    }
    
    func inspectImage(reference: String) async throws -> String {
        do {
            return try await cli.execute(arguments: ["image", "inspect", reference])
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
            _ = try await cli.execute(arguments: ["image", "pull", reference])
        } catch {
            throw AppError(message: "Failed to pull image '\(reference)'", underlyingError: error)
        }
    }
    
    func removeImage(reference: String) async throws {
        do {
            _ = try await cli.execute(arguments: ["image", "delete", reference])
        } catch {
            throw AppError(message: "Failed to remove image '\(reference)'", underlyingError: error)
        }
    }
    
    func tagImage(source: String, target: String) async throws {
        do {
            _ = try await cli.execute(arguments: ["image", "tag", source, target])
        } catch {
            throw AppError(message: "Failed to tag image", underlyingError: error)
        }
    }
    
    func runImage(reference: String, name: String?) async throws {
        var args = ["run", "-d"]
        if let name { args.append(contentsOf: ["--name", name]) }
        args.append(reference)
        
        do {
            _ = try await cli.execute(arguments: args)
        } catch {
            throw AppError(message: "Failed to run image", underlyingError: error)
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
            let name: String
            let tag: String
            
            if let colonIndex = json.reference.lastIndex(of: ":") {
                name = String(json.reference[..<colonIndex])
                tag = String(json.reference[json.reference.index(after: colonIndex)...])
            } else {
                name = json.reference
                tag = "latest"
            }
            
            // descriptor.size is the OCI index manifest size, not the image size.
            // The real size lives in inspect output per-platform variant.
            return ImageInfo(
                id: json.reference,
                name: name,
                tag: tag,
                digest: json.descriptor.digest,
                size: nil,
                createdAt: nil
            )
        }
    }
}
