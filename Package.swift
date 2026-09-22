// swift-tools-version: 5.9
//
//  Package.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── ARCHITECTURE ────────────────────────────────┐
//  │ This file is the Swift Package Manager (SwiftPM) manifest — the single       │
//  │ "project file" for the whole app. SwiftPM is Apple's official build system,  │
//  │ so instead of clicking Run in Xcode we can build from a terminal with:       │
//  │                                                                              │
//  │     swift build                                                              │
//  │                                                                              │
//  │ The package declares ONE product with ONE target:                            │
//  │     • DeepSeekClock → an executable (a program with a `@main` entry point).  │
//  │                                                                              │
//  │ A SwiftPM executable is just a bare binary, NOT a .app bundle. macOS needs a │
//  │ .app bundle + Info.plist to treat it as a real menu bar app (that is where   │
//  │ the "no Dock icon" flag lives). `build.sh` assembles that bundle for us.     │
//  │                                                                              │
//  │ Why a Swift Package instead of a hand-made .xcodeproj?                       │
//  │   • Plain text → easy to read, review and diff.                              │
//  │   • Still opens in Xcode: File ▸ Open… and choose this folder.               │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import PackageDescription

let package = Package(
    // Human-readable name used in build logs and in Xcode.
    name: "DeepSeekClock",

    // Minimum supported OS. `.v13` == macOS Ventura, which is the first
    // release that provides SwiftUI's `MenuBarExtra` scene that this app uses.
    platforms: [
        .macOS(.v13)
    ],

    // Intentionally empty: the app ships with zero third-party dependencies.
    dependencies: [],

    targets: [
        // An `executableTarget` produces a runnable program.
        // `path` points at the folder that contains our .swift source files.
        .executableTarget(
            name: "DeepSeekClock",
            path: "Sources/DeepSeekClock"
        ),

        // Unit tests for the pure business logic (schedule + pricing). SwiftPM
        // supports testing executable targets since Swift 5.5, so the tests can
        // `@testable import DeepSeekClock` without splitting the app into an
        // extra library target. These run in CI, not during normal development.
        .testTarget(
            name: "DeepSeekClockTests",
            dependencies: ["DeepSeekClock"],
            path: "Tests/DeepSeekClockTests"
        )
    ]
)
