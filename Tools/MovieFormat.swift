import Foundation

/// Inspect real sample-group boxes, not coincidental strings in compressed data.
enum MovieFormat {
    static func temporalGroups(in data: Data) -> Set<String> {
        let containers: Set<String> = ["moov", "trak", "mdia", "minf", "stbl"]
        var found = Set<String>()
        func number(_ offset: Int, _ count: Int) -> UInt64 {
            data[offset..<(offset + count)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        }
        func walk(_ start: Int, _ end: Int, _ depth: Int) {
            guard depth < 8 else { return }
            var offset = start
            while offset <= end - 8 {
                let short = number(offset, 4)
                let type = String(bytes: data[(offset + 4)..<(offset + 8)], encoding: .ascii) ?? ""
                let header = short == 1 ? 16 : 8
                guard offset <= end - header else { return }
                let size = short == 0 ? UInt64(end - offset) : (short == 1 ? number(offset + 8, 8) : short)
                guard size >= UInt64(header), size <= UInt64(end - offset) else { return }
                let next = offset + Int(size)
                if containers.contains(type) { walk(offset + header, next, depth + 1) }
                if ["sgpd", "sbgp"].contains(type), next - offset >= header + 8,
                   let group = String(bytes: data[(offset + header + 4)..<(offset + header + 8)], encoding: .ascii) {
                    found.insert(group)
                }
                offset = next
            }
        }
        walk(0, data.count, 0)
        return found
    }

    static func supportsNativeReplay(_ file: URL) throws -> Bool {
        let data = try Data(contentsOf: file, options: .mappedIfSafe)
        return temporalGroups(in: data).isSuperset(of: ["tscl", "tsas"])
    }
}
