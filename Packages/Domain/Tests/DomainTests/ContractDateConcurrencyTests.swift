import Domain
import Foundation
import Testing

/// The shared date formatters must give identical results when used from many threads at once.
struct ContractDateConcurrencyTests {
    private struct Box: Codable, Equatable {
        let at: Date
    }

    @Test func manyThreadsRoundTripDatesIdentically() async {
        let ok = await withTaskGroup(of: Bool.self) { group in
            for worker in 0 ..< 8 {
                group.addTask {
                    let enc = ContractJSON.encoder(), dec = ContractJSON.decoder()
                    for n in 0 ..< 1500 {
                        let date = Date(timeIntervalSince1970: 1_791_716_400 + Double(worker * 10000 + n) + 0.125)
                        guard let data = try? enc.encode(Box(at: date)), let back = try? dec.decode(Box.self, from: data),
                              back.at == date, String(bytes: data, encoding: .utf8)?.contains("Z\"") == true
                        else { return false }
                    }
                    return true
                }
            }
            return await group.allSatisfy(\.self)
        }
        #expect(ok)
    }
}
