import Foundation

enum ByteCountFormat {
    static func string(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file, allowedUnits: [.mb, .gb, .tb], spellsOutZero: true))
    }
}
