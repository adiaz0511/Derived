import Foundation

enum MCPToolDefinitions {
    static let all: [[String: Any]] = [
        [
            "name": "scan",
            "description": "Scan local Xcode, Simulator, and XCTest storage. Returns category summaries and an expiring scan ID. This tool does not delete anything.",
            "inputSchema": objectSchema(properties: [:]),
            "annotations": ["readOnlyHint": true, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false]
        ],
        [
            "name": "list_candidates",
            "description": "List one page of cleanup candidates from a prior Derived scan.",
            "inputSchema": objectSchema(
                properties: [
                    "scan_id": ["type": "string", "format": "uuid"],
                    "category": ["type": "string", "enum": categoryNames],
                    "offset": ["type": "integer", "minimum": 0, "default": 0],
                    "limit": ["type": "integer", "minimum": 1, "maximum": 50, "default": 20]
                ],
                required: ["scan_id", "category"]
            ),
            "annotations": ["readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false]
        ],
        [
            "name": "prepare_cleanup",
            "description": "Prepare an expiring cleanup plan from candidate IDs or complete categories in a prior scan. This does not delete files. Present the returned summary and confirmation phrase to the user before execution.",
            "inputSchema": objectSchema(
                properties: [
                    "scan_id": ["type": "string", "format": "uuid"],
                    "item_ids": ["type": "array", "items": ["type": "string"], "default": []],
                    "categories": ["type": "array", "items": ["type": "string", "enum": categoryNames], "default": []]
                ],
                required: ["scan_id"]
            ),
            "annotations": ["readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false]
        ],
        [
            "name": "execute_cleanup",
            "description": "Permanently delete the targets in an expiring Derived cleanup plan. Invoke only after the user explicitly approves the plan and provides its exact confirmation phrase. Targets are rescanned and revalidated before deletion.",
            "inputSchema": objectSchema(
                properties: [
                    "plan_id": ["type": "string", "format": "uuid"],
                    "confirmation_phrase": ["type": "string"]
                ],
                required: ["plan_id", "confirmation_phrase"]
            ),
            "annotations": ["readOnlyHint": false, "destructiveHint": true, "idempotentHint": false, "openWorldHint": false]
        ]
    ]

    private static let categoryNames = [
        "derivedData", "previewData", "xctestDevices", "unavailableSimulators",
        "redundantSimulators", "simulatorRuntimes", "deviceSupport", "logs",
        "caches", "archives", "temporaryData"
    ]

    private static func objectSchema(
        properties: [String: Any],
        required: [String] = []
    ) -> [String: Any] {
        var schema: [String: Any] = [
            "type": "object",
            "properties": properties,
            "additionalProperties": false
        ]
        if !required.isEmpty {
            schema["required"] = required
        }
        return schema
    }
}
