//
//  ContentView.swift
//  MenuEcho
//
//  Created by 罗文猛 on 2025/2/12.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("Hello, world!")

      // 添加退出按钮
      Button(action: {
        NSApplication.shared.terminate(nil)
      }) {
        Text("退出")
          .foregroundColor(.red)
          .padding()
      }
      .padding(.top, 20)
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
