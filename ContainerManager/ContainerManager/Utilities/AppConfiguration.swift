import Foundation

struct AppConfiguration {
    static var shared = AppConfiguration()
    
    var cliPath: String {
        if let customPath = UserDefaults.standard.string(forKey: "cliPath"),
           FileManager.default.fileExists(atPath: customPath) {
            return customPath
        }
        
        let standardPath = "/usr/local/bin/container"
        if FileManager.default.fileExists(atPath: standardPath) {
            return standardPath
        }
        
        let homebrewPath = "/opt/homebrew/bin/container"
        if FileManager.default.fileExists(atPath: homebrewPath) {
            return homebrewPath
        }
        
        return "/usr/local/bin/container"
    }
    
    var autoRefreshInterval: TimeInterval {
        let value = UserDefaults.standard.double(forKey: "autoRefreshInterval")
        return value > 0 ? value : 3.0
    }
    
    func setCLIPath(_ path: String) {
        UserDefaults.standard.set(path, forKey: "cliPath")
    }
    
    func setAutoRefreshInterval(_ interval: TimeInterval) {
        UserDefaults.standard.set(interval, forKey: "autoRefreshInterval")
    }
    
    func isCLIInstalled() -> Bool {
        FileManager.default.fileExists(atPath: cliPath) &&
        FileManager.default.isExecutableFile(atPath: cliPath)
    }
    
    func isSystemRunning() async -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: cliPath)
        task.arguments = ["list"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
