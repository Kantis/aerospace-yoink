import AppKit

let pidFile = "/tmp/yoink.pid"
let isUnyoink = CommandLine.arguments.contains("--unyoink")

// If an existing daemon is running, signal it and exit
if let pidStr = try? String(contentsOfFile: pidFile, encoding: .utf8)
    .components(separatedBy: "\n").first?
    .trimmingCharacters(in: .whitespacesAndNewlines),
    let pid = pid_t(pidStr),
    pid != getpid(),
    kill(pid, 0) == 0
{
    // Verify the PID is actually a yoink process (guards against stale PID reuse)
    let check = Process()
    let pipe = Pipe()
    check.executableURL = URL(fileURLWithPath: "/bin/ps")
    check.arguments = ["-p", "\(pid)", "-o", "comm="]
    check.standardOutput = pipe
    try? check.run()
    check.waitUntilExit()
    let comm = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if comm.hasSuffix("yoink") {
        kill(pid, isUnyoink ? SIGUSR2 : SIGUSR1)
        exit(0)
    }
    // Stale PID file — fall through to become the new daemon
}

// --unyoink with no running daemon is a no-op
if isUnyoink {
    fputs("yoink: no daemon running\n", stderr)
    exit(1)
}

// Become the daemon — write PID file (clears any old stack data)
let stack = YoinkStack()
let currentPid = getpid()
try? "\(currentPid)".write(toFile: pidFile, atomically: true, encoding: .utf8)

// Clean up PID file on exit
atexit { unlink(pidFile) }

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = YoinkController(stack: stack, pid: currentPid)

// Listen for SIGUSR1 to show panel on subsequent hotkey presses
signal(SIGUSR1, SIG_IGN)
let signalSource = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
signalSource.setEventHandler { controller.activate() }
signalSource.resume()

// Listen for SIGUSR2 to unyoink (pop stack, send window back to origin)
signal(SIGUSR2, SIG_IGN)
let unyoinkSource = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
unyoinkSource.setEventHandler { controller.unyoink() }
unyoinkSource.resume()

// Show immediately on first launch unless started as background daemon
if !CommandLine.arguments.contains("--daemon") && !isUnyoink {
    DispatchQueue.main.async { controller.activate() }
}

app.run()
