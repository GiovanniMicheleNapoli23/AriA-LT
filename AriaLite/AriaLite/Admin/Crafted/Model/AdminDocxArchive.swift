//
//  AdminDocxArchive.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un archivio ZIP quanto basta per un .docx, senza librerie: lettura dalla central directory (voci
//  senza compressione o deflate, tramite il framework Compression: COMPRESSION_ZLIB è deflate
//  grezzo) e scrittura di tutte le voci senza compressione, con il CRC-32 calcolato qui.
//  Niente ZIP64, niente voci cifrate: un rapporto di Aria non ne ha bisogno.
//

import Compression
import Foundation

nonisolated struct AdminDocxArchive: Sendable {
    nonisolated enum Failure: Error, Sendable {
        case notAZip
        case corrupt
        /// ZIP64, cifratura o un metodo di compressione che non è deflate.
        case unsupported
        case tooLarge
    }

    nonisolated struct Entry: Sendable {
        var name: String
        /// Il contenuto già decompresso.
        var data: Data
        var dosTime: UInt16 = 0
        /// 1 gennaio 1980, se la voce è nuova.
        var dosDate: UInt16 = 0x0021
    }

    private(set) var entries: [Entry]

    /// Oltre queste dimensioni (per voce e in tutto) un archivio si rifiuta: protegge da uno ZIP bomba.
    private static let maxEntrySize = 128 << 20
    private static let maxTotalSize = 256 << 20

    init(entries: [Entry] = []) { self.entries = entries }

    func data(of name: String) -> Data? { entries.first { $0.name == name }?.data }

    /// Sostituisce la voce con quel nome, o la aggiunge in fondo.
    mutating func setData(_ data: Data, for name: String) {
        if let index = entries.firstIndex(where: { $0.name == name }) {
            entries[index].data = data
        } else {
            entries.append(Entry(name: name, data: data))
        }
    }

    // MARK: Lettura

    init(data: Data) throws {
        let bytes = [UInt8](data)
        guard bytes.count >= 22 else { throw Failure.notAZip }
        // La fine della central directory sta in coda, dopo al massimo 64 KB di commento.
        var eocd = -1
        var i = bytes.count - 22
        let lowest = max(0, bytes.count - 22 - 0xFFFF)
        while i >= lowest {
            if bytes[i] == 0x50, bytes[i + 1] == 0x4B, bytes[i + 2] == 0x05, bytes[i + 3] == 0x06 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw Failure.notAZip }
        let count = Int(Self.u16(bytes, eocd + 10))
        let directoryOffset = Int(Self.u32(bytes, eocd + 16))
        if count == 0xFFFF || directoryOffset == 0xFFFF_FFFF { throw Failure.unsupported }

        var entries: [Entry] = []
        var total = 0
        var pos = directoryOffset
        for _ in 0..<count {
            guard pos >= 0, pos + 46 <= bytes.count, Self.u32(bytes, pos) == 0x0201_4B50 else { throw Failure.corrupt }
            let flags = Self.u16(bytes, pos + 8)
            let method = Self.u16(bytes, pos + 10)
            let time = Self.u16(bytes, pos + 12)
            let date = Self.u16(bytes, pos + 14)
            let crc = Self.u32(bytes, pos + 16)
            let compressedSize = Int(Self.u32(bytes, pos + 20))
            let size = Int(Self.u32(bytes, pos + 24))
            let nameLength = Int(Self.u16(bytes, pos + 28))
            let extraLength = Int(Self.u16(bytes, pos + 30))
            let commentLength = Int(Self.u16(bytes, pos + 32))
            let localOffset = Int(Self.u32(bytes, pos + 42))
            guard pos + 46 + nameLength <= bytes.count else { throw Failure.corrupt }
            let name = String(decoding: bytes[(pos + 46)..<(pos + 46 + nameLength)], as: UTF8.self)
            pos += 46 + nameLength + extraLength + commentLength
            if flags & 1 != 0 { throw Failure.unsupported }

            // Le cartelle non hanno contenuto.
            if name.hasSuffix("/") {
                entries.append(Entry(name: name, data: Data(), dosTime: time, dosDate: date))
                continue
            }
            guard localOffset + 30 <= bytes.count, Self.u32(bytes, localOffset) == 0x0403_4B50 else { throw Failure.corrupt }
            let start = localOffset + 30 + Int(Self.u16(bytes, localOffset + 26)) + Int(Self.u16(bytes, localOffset + 28))
            let end = start + compressedSize
            guard end <= bytes.count else { throw Failure.corrupt }
            guard size <= Self.maxEntrySize, total + size <= Self.maxTotalSize else { throw Failure.tooLarge }
            total += size

            let content: Data
            switch method {
            case 0:
                guard compressedSize == size else { throw Failure.corrupt }
                content = Data(bytes[start..<end])
            case 8:
                content = try Self.inflate(bytes[start..<end], expected: size)
            default:
                throw Failure.unsupported
            }
            guard Self.crc32(content) == crc else { throw Failure.corrupt }
            entries.append(Entry(name: name, data: content, dosTime: time, dosDate: date))
        }
        self.entries = entries
    }

    private static func u16(_ b: [UInt8], _ at: Int) -> UInt16 { UInt16(b[at]) | UInt16(b[at + 1]) << 8 }

    private static func u32(_ b: [UInt8], _ at: Int) -> UInt32 {
        UInt32(b[at]) | UInt32(b[at + 1]) << 8 | UInt32(b[at + 2]) << 16 | UInt32(b[at + 3]) << 24
    }

    /// Deflate grezzo (senza intestazione zlib), di cui si sa la dimensione finale.
    private static func inflate(_ source: ArraySlice<UInt8>, expected: Int) throws -> Data {
        if expected == 0 { return Data() }
        guard !source.isEmpty else { throw Failure.corrupt }
        var output = [UInt8](repeating: 0, count: expected)
        let written = source.withUnsafeBufferPointer { input in
            output.withUnsafeMutableBufferPointer { out in
                compression_decode_buffer(out.baseAddress!, expected, input.baseAddress!, input.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == expected else { throw Failure.corrupt }
        return Data(output)
    }

    // MARK: Scrittura

    /// Tutte le voci senza compressione (metodo 0), nell'ordine in cui sono.
    func zipped() throws -> Data {
        guard entries.count < 0xFFFF else { throw Failure.tooLarge }
        var out = Data()
        var directory = Data()
        for entry in entries {
            let name = Data(entry.name.utf8)
            guard entry.data.count < 0x7FFF_FFFF, out.count < 0x7FFF_FFFF, name.count <= 0xFFFF else { throw Failure.tooLarge }
            let crc = Self.crc32(entry.data)
            let size = UInt32(entry.data.count)
            let offset = UInt32(out.count)
            // Intestazione locale
            out.appendLE(0x0403_4B50 as UInt32)
            out.appendLE(20 as UInt16)
            out.appendLE(0x0800 as UInt16)  // nomi in UTF-8
            out.appendLE(0 as UInt16)
            out.appendLE(entry.dosTime)
            out.appendLE(entry.dosDate)
            out.appendLE(crc)
            out.appendLE(size)
            out.appendLE(size)
            out.appendLE(UInt16(name.count))
            out.appendLE(0 as UInt16)
            out.append(name)
            out.append(entry.data)
            // Voce della central directory
            directory.appendLE(0x0201_4B50 as UInt32)
            directory.appendLE(20 as UInt16)
            directory.appendLE(20 as UInt16)
            directory.appendLE(0x0800 as UInt16)
            directory.appendLE(0 as UInt16)
            directory.appendLE(entry.dosTime)
            directory.appendLE(entry.dosDate)
            directory.appendLE(crc)
            directory.appendLE(size)
            directory.appendLE(size)
            directory.appendLE(UInt16(name.count))
            directory.appendLE(0 as UInt16)  // extra
            directory.appendLE(0 as UInt16)  // commento
            directory.appendLE(0 as UInt16)  // disco
            directory.appendLE(0 as UInt16)  // attributi interni
            directory.appendLE(0 as UInt32)  // attributi esterni
            directory.appendLE(offset)
            directory.append(name)
        }
        guard out.count + directory.count < 0x7FFF_FFFF else { throw Failure.tooLarge }
        let directoryOffset = UInt32(out.count)
        out.append(directory)
        out.appendLE(0x0605_4B50 as UInt32)
        out.appendLE(0 as UInt16)
        out.appendLE(0 as UInt16)
        out.appendLE(UInt16(entries.count))
        out.appendLE(UInt16(entries.count))
        out.appendLE(UInt32(directory.count))
        out.appendLE(directoryOffset)
        out.appendLE(0 as UInt16)
        return out
    }

    // MARK: CRC-32

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 { value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1 }
        return value
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data { crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFF_FFFF
    }
}

nonisolated extension Data {
    fileprivate mutating func appendLE(_ value: UInt16) { append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8)]) }

    fileprivate mutating func appendLE(_ value: UInt32) {
        append(contentsOf: [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8(value >> 24)])
    }
}
