import Foundation

struct Playlist: Identifiable, Equatable {
    let id: String
    let name: String
    let trackCount: Int
    let ownerName: String
}
