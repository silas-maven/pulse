import Foundation

enum ProcessUtil {
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
