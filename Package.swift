// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "llvm",
    products: [
        .library(name: "llvm", targets: ["ar", "lld", "llc", "clang", "dis", "libLLVM", "link", "lli", "nm", "opt"])
    ],
    dependencies: [
    ],
    targets: [
        .binaryTarget(
            name: "ar",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/ar.xcframework.zip",
            checksum: "fd8f050c823c997abe12f28a2da64c8de0b5f7730c18e9daffc078753bf7718d"
        ),
        .binaryTarget(
            name: "lld",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/lld.xcframework.zip",
            checksum: "c510fba90f82a6f7978b66be2090c07344c32807afe207830aee19badaddee66"
        )
        .binaryTarget(
            name: "llc",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/llc.xcframework.zip",
            checksum: "216620beb3df69c61e680e3394786afce367fae666641fdcdbc05b7420338988"
        ),
        .binaryTarget(
            name: "clang",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/clang.xcframework.zip",
            checksum: "586a8346012c7b300ebbae56506e54f4fa73b3338e4e7689f59cd4ebc3a03bd4"
        ),
        .binaryTarget(
            name: "dis",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/dis.xcframework.zip",
            checksum: "30f2cd4c5fa8c9fcb6a9d7e2765ea90c2aa2704027e6fd8f841e175c6c7c6e23"
        ),
        .binaryTarget(
            name: "libLLVM",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/libLLVM.xcframework.zip",
            checksum: "04cd566981a9fba315f9c9cddf62cdbba26e440b8891619181ee1fcf16596315"
        ),
        .binaryTarget(
            name: "link",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/link.xcframework.zip",
            checksum: "2d68bda344dbd57048e5c54d09a75a951010803f1037961fbd2d568254b55200"
        ),
        .binaryTarget(
            name: "lli",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/lli.xcframework.zip",
            checksum: "0d53a1bc83b23ddc94ea4a56e7a4af928157b5310b7a0c0a6322c6f4e1c80dd9"
        ),
        .binaryTarget(
            name: "nm",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/nm.xcframework.zip",
            checksum: "6f3badd6a407e3dc823a142d429a66cc37a75da32d456fe50ab3f3e6f7b84ff4"
        ),
        .binaryTarget(
            name: "opt",
            url: "https://github.com/holzschu/llvm/releases/download/1.0/opt.xcframework.zip",
            checksum: "910b87ba09daab59ad078d042467c3c71a9bf8bdedd2caca0d1400f3c99f8e90"
        )
    ]
)



/* Merging into xcframeworks:
xcframework successfully written out to: /Users/holzschu/src/Xcode_iPad/llvm/ar.xcframework
fd8f050c823c997abe12f28a2da64c8de0b5f7730c18e9daffc078753bf7718d
xcframework successfully written out to: /Users/holzschu/src/Xcode_iPad/llvm/lld.xcframework
c510fba90f82a6f7978b66be2090c07344c32807afe207830aee19badaddee66
xcframework successfully written out to: /Users/holzschu/src/Xcode_iPad/llvm/llc.xcframework
216620beb3df69c61e680e3394786afce367fae666641fdcdbc05b7420338988
xcframework successfully written out to: /Users/holzschu/src/Xcode_iPad/llvm/clang.xcframework
586a8346012c7b300ebbae56506e54f4fa73b3338e4e7689f59cd4ebc3a03bd4
xcframework successfully written out to: /Users/holzschu/src/Xcode_iPad/llvm/dis.xcframework
30f2cd4c5fa8c9fcb6a9d7e2765ea90c2aa2704027e6fd8f841e175c6c7c6e23
xcframework successfully written out to: /Users/holzschu/src/Xcode_iPad/llvm/libLLVM.xcframework
04cd566981a9fba315f9c9cddf62cdbba26e440b8891619181ee1fcf16596315
xcframework successfully written out to: /Users/holzschu/src/Xcode_iPad/llvm/link.xcframework
2d68bda344dbd57048e5c54d09a75a951010803f1037961fbd2d568254b55200
xcframework successfully written out to: /Users/holzschu/src/Xcode_iPad/llvm/lli.xcframework
0d53a1bc83b23ddc94ea4a56e7a4af928157b5310b7a0c0a6322c6f4e1c80dd9
xcframework successfully written out to: /Users/holzschu/src/Xcode_iPad/llvm/nm.xcframework
6f3badd6a407e3dc823a142d429a66cc37a75da32d456fe50ab3f3e6f7b84ff4
xcframework successfully written out to: /Users/holzschu/src/Xcode_iPad/llvm/opt.xcframework
910b87ba09daab59ad078d042467c3c71a9bf8bdedd2caca0d1400f3c99f8e90 */
