//
//  ShiroPuzzleApp.swift
//  ShiroPuzzle
//
//  Created by Yuki Usui on 2026/02/21.
//
//  フルスクリーン固定: Info.plist の UIRequiresFullScreen = YES により、
//  iPad の Split View / Slide Over を無効化し、常にフルスクリーンで起動します。
//

import SwiftUI

@main
struct ShiroPuzzleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
