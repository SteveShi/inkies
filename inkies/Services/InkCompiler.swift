import Foundation

// MARK: - Compilation Cache
actor CompilationCache {
    static let shared = CompilationCache()

    private var cache: [String: CacheEntry] = [:]
    private let maxCacheSize = 50
    private var accessOrder: [String] = []

    struct CacheEntry {
        let inkCode: String
        let compiledResult: String
        let timestamp: Date
        let hash: String
    }

    func getCachedResult(for inkCode: String) -> String? {
        let codeHash = hashString(inkCode)

        if let entry = cache[codeHash], entry.inkCode == inkCode {
            updateAccessOrder(for: codeHash)
            return entry.compiledResult
        }
        return nil
    }

    func cacheResult(inkCode: String, compiledResult: String) {
        let codeHash = hashString(inkCode)

        if cache.count >= maxCacheSize {
            removeOldestEntry()
        }

        let entry = CacheEntry(
            inkCode: inkCode,
            compiledResult: compiledResult,
            timestamp: Date(),
            hash: codeHash
        )

        cache[codeHash] = entry
        updateAccessOrder(for: codeHash)
    }

    func clearCache() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    private func hashString(_ string: String) -> String {
        let data = Data(string.utf8)
        return data.base64EncodedString()
    }

    private func updateAccessOrder(for hash: String) {
        accessOrder.removeAll { $0 == hash }
        accessOrder.append(hash)
    }

    private func removeOldestEntry() {
        guard !accessOrder.isEmpty else { return }
        let oldestHash = accessOrder.removeFirst()
        cache.removeValue(forKey: oldestHash)
    }
}

// MARK: - Ink Compiler Class
actor InkCompiler {
    static let shared = InkCompiler()
    private var currentProcess: Process?
    private var hasCheckedResources = false

    // Potential paths for inklecate
    private let possiblePaths = [
        "/opt/homebrew/bin/inklecate",
        "/usr/local/bin/inklecate",
    ]

    private var isCompiling = false
    private var pendingCompilation: Task<String, Error>?

    func findInklecate() -> String? {
        
        // 1. Check App Bundle Resources/Compiler (Preferred)
        if let bundledPath = Bundle.main.path(forResource: "inklecate", ofType: nil, inDirectory: "Compiler") {
            print("INKIES DEBUG: Found inklecate in Resources/Compiler: \(bundledPath)")
            return verifiedPath(bundledPath)
        }

        // 2. Check App Bundle Resources (Flat fallback)
        if let bundledPath = Bundle.main.path(forResource: "inklecate", ofType: nil) {
            print("INKIES DEBUG: Found inklecate in Resources (flat): \(bundledPath)")
            return verifiedPath(bundledPath)
        }

        // 3. Check App Bundle Contents/MacOS (Backup location)
        if let execPath = Bundle.main.executablePath {
            let binDir = URL(fileURLWithPath: execPath).deletingLastPathComponent()
            let bundleBin = binDir.appendingPathComponent("inklecate").path
            if FileManager.default.fileExists(atPath: bundleBin) {
                print("INKIES DEBUG: Found inklecate in Contents/MacOS: \(bundleBin)")
                return verifiedPath(bundleBin)
            }
        }

        // 4. System paths
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                print("INKIES DEBUG: Found inklecate in system path: \(path)")
                return verifiedPath(path)
            }
        }

        print("INKIES DEBUG: ERROR - inklecate NOT found in any search location")
        return nil
    }

    private func verifiedPath(_ path: String) -> String? {
        if FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        print("INKIES DEBUG: WARNING - inklecate found at \(path) but is NOT executable")
        // Try to fix permissions if we are not sandboxed
        let attr = [FileAttributeKey.posixPermissions: 0o755]
        do {
            try FileManager.default.setAttributes(attr, ofItemAtPath: path)
            print("INKIES DEBUG: Successfully set executable permission on \(path)")
            return path
        } catch {
            print("INKIES DEBUG: ERROR - Failed to set executable permission on \(path): \(error)")
            // Return it anyway, maybe process.run() will give a better error
            return path
        }
    }

    func analyzeIssues(_ inkCode: String) async -> [InkIssue] {
        do {
            // Run compilation but ignore JSON output, just capture issues
            _ = try await performCompilation(inkCode, captureIssuesOnly: true)
            return []
        } catch let error as NSError {
            if let output = error.userInfo[NSLocalizedDescriptionKey] as? String {
                return parseIssues(from: output)
            }
            return []
        } catch {
            return []
        }
    }

    private func parseIssues(from output: String) -> [InkIssue] {
        var issues: [InkIssue] = []
        let lines = output.components(separatedBy: .newlines)
        
        // Regex to match ERROR: 'temp_...ink' line 2: Message
        // Or WARNING: 'temp_...ink' line 5: Message
        let pattern = #"(ERROR|WARNING): '.*?' line (\d+): (.*)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex?.firstMatch(in: line, options: [], range: range) {
                if let typeRange = Range(match.range(at: 1), in: line),
                   let lineRange = Range(match.range(at: 2), in: line),
                   let msgRange = Range(match.range(at: 3), in: line) {
                    
                    let typeStr = String(line[typeRange])
                    let lineNumber = Int(line[lineRange]) ?? 0
                    let message = String(line[msgRange]).trimmingCharacters(in: .whitespaces)
                    
                    let type: InkIssue.IssueType = typeStr == "WARNING" ? .warning : .error
                    issues.append(InkIssue(type: type, lineNumber: lineNumber, message: message))
                }
            }
        }
        return issues
    }

    func compile(_ inkCode: String) async throws -> String {
        // Check cache first
        if let cachedResult = await CompilationCache.shared.getCachedResult(for: inkCode) {
            return cachedResult
        }

        // Cancel any pending compilation
        pendingCompilation?.cancel()

        // Create new compilation task
        let compilationTask = Task<String, Error> {
            return try await performCompilation(inkCode)
        }

        pendingCompilation = compilationTask

        do {
            let result = try await compilationTask.value
            // Cache the successful result
            await CompilationCache.shared.cacheResult(inkCode: inkCode, compiledResult: result)
            return result
        } catch {
            throw error
        }
    }

    private func performCompilation(_ inkCode: String, captureIssuesOnly: Bool = false) async throws -> String {
        // 0. Build diagnostics (only once)
        if !hasCheckedResources {
            hasCheckedResources = true
            let dlls = ["ink_compiler.dll", "ink-engine-runtime.dll"]
            print("INKIES DEBUG: --- Compiler Diagnostics ---")
            if let resPath = Bundle.main.resourcePath {
                let resURL = URL(fileURLWithPath: resPath)
                let compilerURL = resURL.appendingPathComponent("Compiler")
                for dll in dlls {
                    let exists = FileManager.default.fileExists(atPath: compilerURL.appendingPathComponent(dll).path)
                    print("INKIES DEBUG: \(dll) exists in Resources/Compiler: \(exists)")
                }
                let inklecateExists = FileManager.default.fileExists(
                    atPath: compilerURL.appendingPathComponent("inklecate").path)
                print("INKIES DEBUG: inklecate exists in Compiler/: \(inklecateExists)")
                if inklecateExists {
                    let isExec = FileManager.default.isExecutableFile(
                        atPath: resURL.appendingPathComponent("inklecate").path)
                    print("INKIES DEBUG: inklecate is executable: \(isExec)")
                }
            }
        }

        // Interrupt any existing process
        if let existing = currentProcess, existing.isRunning {
            existing.terminate()
            print("INKIES DEBUG: Terminated previous compilation process")
        }

        guard let compilerPath = findInklecate() else {
            print("INKIES DEBUG: ERROR - compiler path not found")
            throw NSError(
                domain: "InkCompiler", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "inklecate compiler not found in bundle."])
        }

        // 1. Prepare temporary files
        let uuid = UUID().uuidString
        let tempDir = FileManager.default.temporaryDirectory
        let tempInkFile = tempDir.appendingPathComponent("temp_\(uuid).ink")
        let tempJsonFile = tempDir.appendingPathComponent("temp_\(uuid).json")

        do {
            try inkCode.write(to: tempInkFile, atomically: true, encoding: .utf8)
        } catch {
            throw NSError(
                domain: "InkCompiler", code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to write temp file: \(error.localizedDescription)"
                ])
        }

        // 2. Run inklecate process
        let process = Process()
        let compilerURL = URL(fileURLWithPath: compilerPath)
        process.executableURL = compilerURL
        process.arguments = ["-o", tempJsonFile.path, tempInkFile.path]

        // Set working directory to where inklecate is, so it finds DLLs
        process.currentDirectoryURL = compilerURL.deletingLastPathComponent()

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        print("INKIES DEBUG: Starting compilation: \(compilerPath)")

        self.currentProcess = process

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { process in
                    let status = process.terminationStatus
                    let outData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let outStr = String(data: outData, encoding: .utf8) ?? ""
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    let combinedOutput = outStr + "\n" + errStr

                    if status == 0 {
                        if captureIssuesOnly {
                            continuation.resume(returning: "")
                        } else {
                            do {
                                if FileManager.default.fileExists(atPath: tempJsonFile.path) {
                                    let jsonData = try Data(contentsOf: tempJsonFile)
                                    let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
                                    continuation.resume(returning: jsonString)
                                } else {
                                    if outStr.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
                                        continuation.resume(returning: outStr)
                                    } else {
                                        throw NSError(domain: "InkCompiler", code: 500, 
                                            userInfo: [NSLocalizedDescriptionKey: "Compiler exited 0 but temp.json missing and stdout not JSON.\nSTDOUT: \(outStr)\nSTDERR: \(errStr)"])
                                    }
                                }
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        var errorMsg = combinedOutput
                        if errorMsg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            errorMsg = "Compiler failed with exit code \(status) (No output message)"
                        }
                        
                        continuation.resume(
                            throwing: NSError(
                                domain: "InkCompiler", code: Int(status),
                                userInfo: [NSLocalizedDescriptionKey: errorMsg]))
                    }

                    // Cleanup temp files
                    try? FileManager.default.removeItem(at: tempInkFile)
                    try? FileManager.default.removeItem(at: tempJsonFile)
                }

                do {
                    try process.run()
                } catch {
                    print(
                        "INKIES DEBUG: ERROR - failed to run process: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
                print("INKIES DEBUG: Compiling task canceled, terminated process")
            }
        }
    }
}
