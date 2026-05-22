import Foundation
import Darwin

@main
struct ToughScanPrivacyChecks {
    static func main() {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let scanner = PrivacyLoggingScanner(rootURL: rootURL)
        let findings: [PrivacyFinding]

        do {
            findings = try scanner.scan()
        } catch {
            FileHandle.standardError.writeLine("Privacy logging check could not scan source files.")
            exit(EXIT_FAILURE)
        }

        guard findings.isEmpty else {
            for finding in findings {
                FileHandle.standardError.writeLine(finding.description)
            }
            exit(EXIT_FAILURE)
        }

        print("ToughScanPrivacyChecks passed")
    }
}

private struct PrivacyLoggingScanner {
    private let rootURL: URL
    private let fileManager: FileManager
    private let scannedDirectories = ["ToughScan", "Sources/ToughScanCore"]
    private let rules = LoggingRule.defaultRules

    init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    func scan() throws -> [PrivacyFinding] {
        var findings: [PrivacyFinding] = []

        for directory in scannedDirectories {
            let directoryURL = rootURL.appendingPathComponent(directory, isDirectory: true)
            guard fileManager.fileExists(atPath: directoryURL.path) else {
                continue
            }

            let swiftFiles = try swiftSourceFiles(in: directoryURL)
            for fileURL in swiftFiles {
                let source = try String(contentsOf: fileURL, encoding: .utf8)
                let relativePath = fileURL.path.replacingOccurrences(
                    of: rootURL.path + "/",
                    with: ""
                )
                findings.append(contentsOf: inspect(source, relativePath: relativePath))
            }
        }

        return findings.sorted()
    }

    private func swiftSourceFiles(in directoryURL: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let fileURL = item as? URL,
                  fileURL.pathExtension == "swift" else {
                return nil
            }

            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? fileURL : nil
        }
    }

    private func inspect(_ source: String, relativePath: String) -> [PrivacyFinding] {
        var findings: [PrivacyFinding] = []
        var isInsideBlockComment = false
        var isInsideMultilineString = false

        for (lineOffset, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let code = Self.codeOnlyFragment(
                from: String(line),
                isInsideBlockComment: &isInsideBlockComment,
                isInsideMultilineString: &isInsideMultilineString
            )
            let range = NSRange(code.startIndex..<code.endIndex, in: code)

            for rule in rules where rule.regex.firstMatch(in: code, range: range) != nil {
                findings.append(PrivacyFinding(
                    relativePath: relativePath,
                    lineNumber: lineOffset + 1,
                    apiName: rule.apiName
                ))
            }
        }

        return findings
    }

    private static func codeOnlyFragment(
        from line: String,
        isInsideBlockComment: inout Bool,
        isInsideMultilineString: inout Bool
    ) -> String {
        var output = ""
        var index = line.startIndex
        var isInsideString = false
        var isEscaped = false

        while index < line.endIndex {
            if isInsideMultilineString {
                if line[index...].hasPrefix("\"\"\"") {
                    isInsideMultilineString = false
                    index = line.index(index, offsetBy: 3)
                } else {
                    index = line.index(after: index)
                }
                continue
            }

            if isInsideBlockComment {
                if line[index...].hasPrefix("*/") {
                    isInsideBlockComment = false
                    index = line.index(index, offsetBy: 2)
                } else {
                    index = line.index(after: index)
                }
                continue
            }

            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if line[index] == "\\" {
                    isEscaped = true
                } else if line[index] == "\"" {
                    isInsideString = false
                }
                index = line.index(after: index)
                continue
            }

            if line[index...].hasPrefix("//") {
                break
            }

            if line[index...].hasPrefix("/*") {
                isInsideBlockComment = true
                index = line.index(index, offsetBy: 2)
                continue
            }

            if line[index...].hasPrefix("\"\"\"") {
                isInsideMultilineString = true
                index = line.index(index, offsetBy: 3)
                continue
            }

            if line[index] == "\"" {
                isInsideString = true
                index = line.index(after: index)
                continue
            }

            output.append(line[index])
            index = line.index(after: index)
        }

        return output
    }
}

private struct LoggingRule {
    let apiName: String
    let regex: NSRegularExpression

    static let defaultRules: [LoggingRule] = [
        rule(apiName: "print", pattern: #"\bprint\s*\("#),
        rule(apiName: "debugPrint", pattern: #"\bdebugPrint\s*\("#),
        rule(apiName: "NSLog", pattern: #"\bNSLog\s*\("#),
        rule(apiName: "Logger", pattern: #"\bLogger\s*\("#),
        rule(apiName: "os_log", pattern: #"\bos_log\s*\("#),
        rule(apiName: "OSLog", pattern: #"\bOSLog\s*\("#)
    ]

    private static func rule(apiName: String, pattern: String) -> LoggingRule {
        do {
            return LoggingRule(
                apiName: apiName,
                regex: try NSRegularExpression(pattern: pattern)
            )
        } catch {
            fatalError("Invalid privacy logging rule for \(apiName): \(error)")
        }
    }
}

private struct PrivacyFinding: Comparable, CustomStringConvertible {
    let relativePath: String
    let lineNumber: Int
    let apiName: String

    var description: String {
        "\(relativePath):\(lineNumber): disallowed logging API '\(apiName)'"
    }

    static func < (lhs: PrivacyFinding, rhs: PrivacyFinding) -> Bool {
        if lhs.relativePath != rhs.relativePath {
            return lhs.relativePath < rhs.relativePath
        }

        if lhs.lineNumber != rhs.lineNumber {
            return lhs.lineNumber < rhs.lineNumber
        }

        return lhs.apiName < rhs.apiName
    }
}

private extension FileHandle {
    func writeLine(_ line: String) {
        if let data = "\(line)\n".data(using: .utf8) {
            write(data)
        }
    }
}
