import Foundation

struct FolderConfigDTO: Codable {
    let defaultBranch: String
}

struct FolderConfigStore {

    static let fallback = FolderConfigDTO(defaultBranch: "main")

    func save(_ config: FolderConfigDTO, at repoURL: URL) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: configURL(at: repoURL))
    }

    func load(at repoURL: URL) -> FolderConfigDTO {
        guard let data = try? Data(contentsOf: configURL(at: repoURL)),
              let config = try? JSONDecoder().decode(FolderConfigDTO.self, from: data) else {
            return Self.fallback
        }
        return config
    }

    // MARK: - Private

    private func configURL(at repoURL: URL) -> URL {
        repoURL
            .appendingPathComponent(".git")
            .appendingPathComponent("noteblob.json")
    }
}
