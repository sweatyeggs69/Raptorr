import Testing
@testable import Raptorr

struct WikipediaClientTests {
    @Test func acceptsPerformersOnly() {
        let actor = WikipediaSummary(type: "standard", description: "Canadian-American actor and comedian (born 1962)", extract: "Bio")
        let other = WikipediaSummary(type: "standard", description: "American politician", extract: "Bio")

        #expect(WikipediaClient.isPerformer(actor))
        #expect(!WikipediaClient.isPerformer(other))
    }
}
