//
//  MenuEchoApp.swift
//  MenuEcho
//
//  Created by 罗文猛 on 2025/2/12.
//

import AppKit
import Combine
import Network
import SwiftUI

@main
struct app2502120App: App {
  @StateObject private var httpServer: HTTPServer
  @StateObject private var statusBarController: StatusBarController

  init() {
    // 设置应用程序不在Dock中显示
    NSApplication.shared.setActivationPolicy(.accessory)

    let server = HTTPServer()
    _httpServer = StateObject(wrappedValue: server)
    _statusBarController = StateObject(wrappedValue: StatusBarController(httpServer: server))
  }

  var body: some Scene {
    Settings {
      EmptyView()
    }
    .commands {
      // 移除所有默认菜单
      CommandGroup(replacing: .appInfo) {}
      CommandGroup(replacing: .systemServices) {}
      CommandGroup(replacing: .newItem) {}
    }
  }
}

class HTTPServer: ObservableObject {
  private var listener: NWListener?
  @Published var lastResponse: String = ""

  init() {
    setupServer()
  }

  private func setupServer() {
    do {
      // 创建TCP监听器
      let parameters = NWParameters.tcp
      listener = try NWListener(using: parameters, on: 15098)

      listener?.stateUpdateHandler = { [weak self] state in
        switch state {
        case .ready:
          print("HTTP服务器已启动, 监听端口 15098")
        case .failed(let error):
          print("服务器错误: \(error)")
          self?.restart()
        default:
          break
        }
      }

      listener?.newConnectionHandler = { [weak self] connection in
        self?.handleConnection(connection)
      }

      listener?.start(queue: .main)
    } catch {
      print("启动服务器失败: \(error)")
    }
  }

  private func handleConnection(_ connection: NWConnection) {
    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        self.receiveData(connection)
      case .failed(let error):
        print("连接错误: \(error)")
        connection.cancel()
      default:
        break
      }
    }

    connection.start(queue: .main)
  }

  private func receiveData(_ connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
      [weak self] content, _, isComplete, error in
      if let data = content,
        let request = String(data: data, encoding: .utf8)
      {
        print("收到请求: \(request)")

        // 解析请求中的参数
        var paramValue = ""
        if let paramRange = request.range(of: "param="),
          let endOfParamRange = request.range(
            of: " ", range: paramRange.upperBound..<request.endIndex)
        {
          paramValue = String(request[paramRange.upperBound..<endOfParamRange.lowerBound])
        }

        // 发送参数值作为响应，添加换行符
        let responseBody = paramValue + "\n"
        let response = """
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: \(responseBody.utf8.count)

          \(responseBody)
          """
        self?.sendResponse(response, on: connection)
      }

      if error != nil || isComplete {
        connection.cancel()
      } else {
        self?.receiveData(connection)
      }
    }
  }

  private func sendResponse(_ response: String, on connection: NWConnection) {
    guard let data = response.data(using: .utf8) else { return }

    if let bodyStart = response.range(of: "\n\n")?.upperBound {
      let bodyText = String(response[bodyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
      DispatchQueue.main.async {
        print("更新 lastResponse: \(bodyText)")
        self.lastResponse = bodyText
      }
    }

    connection.send(content: data, completion: .idempotent)
  }

  private func restart() {
    listener?.cancel()
    setupServer()
  }

  deinit {
    listener?.cancel()
  }
}

class StatusBarController: ObservableObject {
  private var statusBar: NSStatusBar
  private var statusItem: NSStatusItem
  private var popover: NSPopover?
  @ObservedObject var httpServer: HTTPServer
  private var cancellables = Set<AnyCancellable>()

  init(httpServer: HTTPServer) {
    self.httpServer = httpServer
    statusBar = NSStatusBar.system
    statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)

    setupPopover()
    setupStatusItem()
    setupObserver()
  }

  private func setupPopover() {
    popover = NSPopover()
    popover?.contentSize = NSSize(width: 300, height: 300)
    popover?.behavior = .transient
    popover?.contentViewController = NSHostingController(rootView: ContentView())
  }

  private func setupStatusItem() {
    if let button = statusItem.button {
      button.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Star")
      button.action = #selector(togglePopover(_:))
      button.target = self
      updateDisplay()
    }
  }

  private func setupObserver() {
    httpServer.objectWillChange
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateDisplay()
      }
      .store(in: &cancellables)
  }

  private func updateDisplay() {
    guard let button = statusItem.button else { return }

    let text = httpServer.lastResponse.isEmpty ? "等待数据..." : httpServer.lastResponse
    print("状态栏更新: \(text)")

    let lightGreen = NSColor(red: 144 / 255, green: 238 / 255, blue: 144 / 255, alpha: 1.0)
    let attributes: [NSAttributedString.Key: Any] = [
      .foregroundColor: lightGreen
    ]

    button.attributedTitle = NSAttributedString(string: text, attributes: attributes)
  }

  @objc func togglePopover(_ sender: AnyObject?) {
    guard let button = statusItem.button,
      let popover = popover
    else { return }

    if popover.isShown {
      popover.performClose(sender)
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
    }
  }

  deinit {
    cancellables.removeAll()
  }
}
