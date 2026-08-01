import Testing
@testable import Derived

struct PathDisplayFormatTests {
    @Test func formatsHomeLocationWithoutUsernameOrLeaf() {
        let result = PathDisplayFormat.location(
            for: "/Users/example/Library/Developer/Xcode/DerivedData/Example-hash",
            homeDirectory: "/Users/example"
        )

        #expect(result == "Home › Library › Developer › Xcode › Derived Data")
    }

    @Test func formatsVolumeLocationWithoutVolumesPrefixOrLeaf() {
        let result = PathDisplayFormat.location(
            for: "/Volumes/External/Xcode/Archives/Application.xcarchive",
            homeDirectory: "/Users/example"
        )

        #expect(result == "External › Xcode › Archives")
    }

    @Test func formatsVirtualLocationAsBreadcrumb() {
        let result = PathDisplayFormat.location(
            for: "simctl://runtime/com.apple.CoreSimulator.SimRuntime.iOS-26-5",
            homeDirectory: "/Users/example"
        )

        #expect(result == "simctl › runtime")
    }
}
