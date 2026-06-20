//
//  AncientsCSV.swift
//  BattleCalc
//
//  Small CSV helpers for Ancients-owned data files.
//

import Foundation

enum AncientsCSVError: Error, LocalizedError {
    case fileNotFound(String)
    case unreadableFile(String)
    case missingHeader(String, fileName: String)
    case invalidValue(field: String, value: String, rowID: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "Could not find \(fileName) in the app bundle."
        case .unreadableFile(let fileName):
            return "Could not read \(fileName) from the app bundle."
        case .missingHeader(let header, let fileName):
            return "\(fileName) is missing required column header '\(header)'."
        case .invalidValue(let field, let value, let rowID):
            return "Invalid value '\(value)' for field '\(field)' in row '\(rowID)'."
        }
    }
}

enum AncientsCSV {
    static func loadRows(resourceName: String, requiredHeaders: [String]) throws -> [[String: String]] {
        let fileName = "\(resourceName).csv"
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "csv") else {
            throw AncientsCSVError.fileNotFound(fileName)
        }

        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw AncientsCSVError.unreadableFile(fileName)
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let headerLine = lines.first else { return [] }
        let headers = splitLine(headerLine).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var headerIndex: [String: Int] = [:]
        for (index, header) in headers.enumerated() where !header.isEmpty {
            if headerIndex[header] == nil { headerIndex[header] = index }
        }

        for requiredHeader in requiredHeaders where headerIndex[requiredHeader] == nil {
            throw AncientsCSVError.missingHeader(requiredHeader, fileName: fileName)
        }

        return lines.dropFirst().map { line in
            let cells = splitLine(line)
            var row: [String: String] = [:]
            for (header, index) in headerIndex {
                row[header] = index < cells.count ? cells[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            }
            return row
        }
    }

    static func splitLine(_ line: String) -> [String] {
        var cells: [String] = []
        var current = ""
        var isInsideQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                let nextIndex = line.index(after: index)
                if isInsideQuotes, nextIndex < line.endIndex, line[nextIndex] == "\"" {
                    current.append("\"")
                    index = nextIndex
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == ",", !isInsideQuotes {
                cells.append(current)
                current = ""
            } else {
                current.append(character)
            }
            index = line.index(after: index)
        }

        cells.append(current)
        return cells
    }

    static func int(_ value: String, field: String, rowID: String) throws -> Int {
        guard let parsed = Int(value) else {
            throw AncientsCSVError.invalidValue(field: field, value: value, rowID: rowID)
        }
        return parsed
    }

    static func optionalInt(_ value: String, field: String, rowID: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.uppercased() == "NA" { return nil }
        return Int(trimmed)
    }

    static func bool(_ value: String, field: String, rowID: String) throws -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "TRUE", "YES", "1":
            return true
        case "FALSE", "NO", "0", "", "NA":
            return false
        default:
            throw AncientsCSVError.invalidValue(field: field, value: value, rowID: rowID)
        }
    }
}
