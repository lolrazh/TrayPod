import Foundation

struct Album: Identifiable, Equatable {
    let id: String
    let name: String
    let artistName: String
    let trackCount: Int
}
