import Foundation

/// Mirrors the WKContentRuleList JSON structure for `AdBlockRules.json`.
struct BlockedAdsRule: Codable {
    let trigger: Trigger
    let action: Action

    struct Trigger: Codable {
        let urlFilter: String
        let resourceType: [String]?

        enum CodingKeys: String, CodingKey {
            case urlFilter   = "url-filter"
            case resourceType = "resource-type"
        }
    }

    struct Action: Codable {
        let type: String
    }
}
