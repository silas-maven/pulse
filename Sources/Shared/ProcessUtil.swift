import Foundation

enum ProcessUtil {
    /// Get all listening TCP ports and their PIDs in a single lsof call.
    /// Returns [port: pid]. Much cheaper than calling lsof per-port.
    static func allListeningPorts() -> [Int: Int] {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        proc.arguments = ["-iTCP", "-sTCP:LISTEN", "-nP", "-Fn"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return [:]
        }
        guard proc.terminationStatus == 0 else { return [:] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        var result: [Int: Int] = [:]
        var currentPid: Int?
        for line in output.split(separator: "\n") {
            if line.hasPrefix("p") {
                currentPid = Int(line.dropFirst())
            } else if line.hasPrefix("n") && line.contains(":") {
                if let pid = currentPid,
                   let portStr = line.split(separator: ":").last,
                   let port = Int(portStr) {
                    result[port] = pid
                }
            }
        }
        return result
    }

    /// Check if a port is being listened on. Returns the PID if found.
    static func pidListeningOn(port: Int) -> Int? {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        proc.arguments = ["-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int(str.components(separatedBy: "\n").first ?? "") else {
            return nil
        }
        return pid
    }

    /// Check if a PID is alive.
    static func isAlive(pid: Int) -> Bool {
        kill(Int32(pid), 0) == 0
    }

    /// Read PID from a pid file.
    static func readPidFile(_ path: String) -> Int? {
        let expanded = NSString(string: path).expandingTildeInPath
        guard let contents = try? String(contentsOfFile: expanded, encoding: .utf8) else { return nil }
        return Int(contents.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Send SIGTERM to a PID. If still alive after `graceSeconds`, send SIGKILL.
    static func terminate(pid: Int, graceSeconds: TimeInterval = 5) {
        kill(Int32(pid), SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + graceSeconds) {
            if isAlive(pid: pid) {
                kill(Int32(pid), SIGKILL)
            }
        }
    }

    /// Find PID of a running `portless <name>` process.
    static func pidOfPortlessApp(name: String) -> Int? {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-f", "portless \(name)"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch { return nil }
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int(str.components(separatedBy: "\n").first ?? "") else {
            return nil
        }
        return pid
    }

    /// Kill a process and all its children by walking the process tree.
    /// Process group kill alone isn't reliable when spawned via shell wrappers.
    static func terminateTree(pid: Int, graceSeconds: TimeInterval = 5) {
        // Find all child PIDs recursively using pgrep -P
        let children = childPids(of: pid)

        // Kill children first (deepest first), then parent
        for child in children.reversed() {
            kill(Int32(child), SIGTERM)
        }
        // Kill the process group (in case it IS the leader)
        kill(-Int32(pid), SIGTERM)
        kill(Int32(pid), SIGTERM)

        DispatchQueue.global().asyncAfter(deadline: .now() + graceSeconds) {
            for child in children {
                if isAlive(pid: child) { kill(Int32(child), SIGKILL) }
            }
            if isAlive(pid: pid) {
                kill(-Int32(pid), SIGKILL)
                kill(Int32(pid), SIGKILL)
            }
        }
    }

    /// Recursively find all child PIDs of a given PID.
    private static func childPids(of parentPid: Int) -> [Int] {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-P", "\(parentPid)"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch { return [] }
        guard proc.terminationStatus == 0 else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8) else { return [] }

        var result: [Int] = []
        for line in str.split(separator: "\n") {
            if let pid = Int(line) {
                result.append(pid)
                // Recurse to get grandchildren
                result.append(contentsOf: childPids(of: pid))
            }
        }
        return result
    }

    /// Spawn a shell command in the background. Returns the PID.
    @discardableResult
    static func spawn(command: String, logFile: String?) -> Int {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Source profile so PATH includes homebrew, pnpm, etc.
        proc.arguments = ["-l", "-c", command]

        if let logPath = logFile {
            let expanded = NSString(string: logPath).expandingTildeInPath
            FileManager.default.createFile(atPath: expanded, contents: nil)
            let handle = FileHandle(forWritingAtPath: expanded) ?? FileHandle.nullDevice
            proc.standardOutput = handle
            proc.standardError = handle
        } else {
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
        }

        do {
            try proc.run()
        } catch {
            return -1
        }
        return Int(proc.processIdentifier)
    }
}
