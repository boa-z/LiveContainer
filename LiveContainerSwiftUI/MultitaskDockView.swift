//
//  MultitaskDockView.swift
//  LiveContainer
//
//  Created by boa-z on 2025/6/28.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - App Model for Dock
@objc class DockAppModel: NSObject, ObservableObject, Identifiable {
    let id = UUID()
    @objc let appName: String
    @objc let appUUID: String
    let appInfo: LCAppInfo?
    
    @objc init(appName: String, appUUID: String, appInfo: LCAppInfo? = nil) {
        self.appName = appName
        self.appUUID = appUUID
        self.appInfo = appInfo
        super.init()
    }
}

// MARK: - MultitaskDockView Manager
@objc public class MultitaskDockManager: NSObject, ObservableObject {
    @objc public static let shared = MultitaskDockManager()
    
    @Published var apps: [DockAppModel] = []
    @Published var isVisible: Bool = false
    @Published var isCollapsed: Bool = false
    @Published var isDockHidden: Bool = false
    @Published var settingsChanged: Bool = false
    
    internal var hostingController: UIHostingController<AnyView>?
    private var hiddenPosition: CGFloat = 0
    
    // Original dock width from user settings (without auto-adjustment)
    private var originalDockWidth: CGFloat {
        let storedValue = LCUtils.appGroupUserDefault.double(forKey: "LCDockWidth")
        return storedValue > 0 ? CGFloat(storedValue) : 90
    }
    
    // Calculate adaptive dock width (auto-adjust when exceeding safe area)
    public var dockWidth: CGFloat {
        guard apps.count > 0 else { return originalDockWidth }
        
        let screenBounds = UIScreen.main.bounds
        var safeAreaHeight = screenBounds.height
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first {
            if #available(iOS 11.0, *) {
                let safeAreaInsets = keyWindow.safeAreaInsets
                safeAreaHeight = screenBounds.height - safeAreaInsets.top - safeAreaInsets.bottom
            }
        }
        
        let additionalTopMargin: CGFloat = 20
        let additionalBottomMargin: CGFloat = 20
        let availableHeight = safeAreaHeight - additionalTopMargin - additionalBottomMargin
        
        let padding: CGFloat = 60
        let maxSafeHeight = availableHeight * 0.85
        let userWidth = originalDockWidth
        
        let iconSize = calculateIconSize(for: userWidth)
        
        let requiredHeight = CGFloat(apps.count) * iconSize + padding
        
        if requiredHeight > maxSafeHeight {
            let maxIconSize = (maxSafeHeight - padding) / CGFloat(apps.count)
            let minIconSize: CGFloat = 30
            let targetIconSize = max(minIconSize, maxIconSize)
            
            let targetWidth = targetIconSize / 0.75
            let minWidth: CGFloat = 50
            
            return max(minWidth, targetWidth)
        }
        
        return userWidth
    }
    
    // Calculate icon size based on dock width
    private func calculateIconSize(for width: CGFloat) -> CGFloat {
        let iconSize = width * 0.75
        let minSize: CGFloat = 30
        let maxSize: CGFloat = 100
        return max(minSize, min(maxSize, iconSize))
    }
    
    // Calculate adaptive icon size
    public var adaptiveIconSize: CGFloat {
        return calculateIconSize(for: dockWidth)
    }
    
    override init() {
        super.init()
        setupDockView()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: LCUtils.appGroupUserDefault
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func userDefaultsDidChange() {
        DispatchQueue.main.async {
            self.settingsChanged.toggle()
            if self.isVisible {
                self.updateDockFrame()
            }
        }
    }
    
    private func setupDockView() {
        let dockView = AnyView(MultitaskDockSwiftView()
            .environmentObject(self))
        
        hostingController = UIHostingController(rootView: dockView)
        hostingController?.view.backgroundColor = .clear
    }

    private func updateDockFrame(animated: Bool = true) {
        guard isVisible, let hostingController = hostingController else { return }

        let screenBounds = UIScreen.main.bounds
        let currentDockWidth = dockWidth
        
        var safeAreaHeight = screenBounds.height
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first {
            if #available(iOS 11.0, *) {
                let safeAreaInsets = keyWindow.safeAreaInsets
                safeAreaHeight = screenBounds.height - safeAreaInsets.top - safeAreaInsets.bottom
            }
        }
        
        let dockHeight: CGFloat
        if isCollapsed {
            let minCollapsedHeight: CGFloat = 60
            let minSize: CGFloat = 44
            let maxSize: CGFloat = 80
            let targetSize = currentDockWidth * 0.7
            let buttonSize = max(minSize, min(maxSize, targetSize))
            let collapsedHeight = buttonSize + 30
            dockHeight = max(minCollapsedHeight, collapsedHeight)
        } else {
            let padding: CGFloat = 60
            let currentIconSize = adaptiveIconSize
            dockHeight = CGFloat(self.apps.count) * currentIconSize + padding
        }

        let currentFrame = hostingController.view.frame
        let currentCenterX = currentFrame.midX
        let isOnRightSide = currentCenterX > screenBounds.width / 2
        
        var targetX: CGFloat
        if isDockHidden {
            if isOnRightSide {
                targetX = screenBounds.width - 25
            } else {
                targetX = -currentDockWidth + 25
            }
        } else {
            if isOnRightSide {
                targetX = screenBounds.width - currentDockWidth
            } else {
                targetX = 0
            }
        }
        
        let targetY: CGFloat
        var safeAreaTopInset: CGFloat = 0
        var safeAreaBottomInset: CGFloat = 0
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first {
            if #available(iOS 11.0, *) {
                safeAreaTopInset = keyWindow.safeAreaInsets.top
                safeAreaBottomInset = keyWindow.safeAreaInsets.bottom
            }
        }
        
        let additionalTopMargin: CGFloat = 30
        let additionalBottomMargin: CGFloat = 30
        
        let safeAreaMinY = safeAreaTopInset + additionalTopMargin
        let safeAreaMaxY = screenBounds.height - safeAreaBottomInset - dockHeight - additionalBottomMargin
        
        if currentFrame.height > 0 {
            let currentCenterY = currentFrame.midY
            let desiredY = currentCenterY - dockHeight / 2
            targetY = max(safeAreaMinY, min(safeAreaMaxY, desiredY))
        } else {
            let safeAreaCenterY = safeAreaMinY + (safeAreaMaxY - safeAreaMinY + dockHeight) / 2
            targetY = max(safeAreaMinY, min(safeAreaMaxY, safeAreaCenterY - dockHeight / 2))
        }

        let newFrame = CGRect(
            x: targetX,
            y: targetY,
            width: currentDockWidth,
            height: dockHeight
        )
        
        if animated {
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3,
                options: .curveEaseOut
            ) {
                hostingController.view.frame = newFrame
            }
        } else {
            hostingController.view.frame = newFrame
        }
    }
    
    @objc public func addRunningApp(_ appName: String, appUUID: String) {
        guard isDockEnabled() else { return }
        
        if apps.contains(where: { $0.appUUID == appUUID }) {
            return
        }
        
        let appInfo = findAppInfoFromSharedModel(appName: appName, dataUUID: appUUID) 
                      ?? findAppInfoByDataUUID(appUUID) 
                      ?? findAppInfoByName(appName)
        
        let appModel = DockAppModel(appName: appName, appUUID: appUUID, appInfo: appInfo)
        
        if appInfo != nil {
            NSLog("[Dock] Successfully found appInfo for app: \(appName) with UUID: \(appUUID)")
        } else {
            NSLog("[Dock] Warning: Could not find appInfo for app: \(appName) with UUID: \(appUUID)")
        }
        
        DispatchQueue.main.async {
            self.apps.append(appModel)
            
            if self.apps.count == 1 {
                self.showDock()
            } else if self.isVisible {
            self.updateDockFrame()
        }
        }
    }
    
    @objc public func removeRunningApp(_ appUUID: String) {
        guard isDockEnabled() else { return }
        
        DispatchQueue.main.async {
            self.apps.removeAll { $0.appUUID == appUUID }
            
            if self.apps.isEmpty {
                self.hideDock()
            } else if self.isVisible {
                self.updateDockFrame()
            }
        }
    }
    
    @objc public func showDock() {
        guard isDockEnabled() else { return }
        
        guard !isVisible, let hostingController = hostingController else { return }
        
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let keyWindow = windowScene.windows.first else { return }
            
            self.isVisible = true
            
            let screenBounds = UIScreen.main.bounds
            let currentDockWidth = self.dockWidth
            hostingController.view.frame = CGRect(
                x: screenBounds.width - currentDockWidth,
                y: (screenBounds.height - 120) / 2,
                width: currentDockWidth,
                height: 120
            )
            self.updateDockFrame(animated: false) 
            
            keyWindow.addSubview(hostingController.view)
            
            self.setupEdgeGestureRecognizers()
            
            hostingController.view.alpha = 0
            hostingController.view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.5,
                options: .curveEaseOut
            ) {
                hostingController.view.alpha = 1
                hostingController.view.transform = .identity
            }
        }
    }
    
    @objc public func hideDock() {
        guard isVisible, let hostingController = hostingController else { return }
        
        DispatchQueue.main.async {
            UIView.animate(
                withDuration: 0.3,
                animations: {
                    hostingController.view.alpha = 0
                    hostingController.view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                },
                completion: { _ in
                    hostingController.view.removeFromSuperview()
                    self.isVisible = false
                }
            )
        }
    }
    
    @objc public func updateDockPosition(translation: CGSize) {
        guard let hostingController = hostingController else { return }
        
        DispatchQueue.main.async {
            let screenWidth = UIScreen.main.bounds.width
            let screenHeight = UIScreen.main.bounds.height
            
            let currentFrame = hostingController.view.frame
            let newX = currentFrame.origin.x + translation.width
            let newY = currentFrame.origin.y + translation.height
            
            let horizontalDistance = abs(translation.width)
            let verticalDistance = abs(translation.height)
            
            if horizontalDistance > verticalDistance && horizontalDistance > 60 {
                let isOnRightSide = currentFrame.origin.x > screenWidth / 2
                
                if (isOnRightSide && translation.width > 0) || (!isOnRightSide && translation.width < 0) {
                    self.isDockHidden = true
                    
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    self.updateDockFrame()
                    self.setupEdgeGestureRecognizers()
                    return
                } else if self.isDockHidden {
                    self.isDockHidden = false
                    
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    self.updateDockFrame()
                    self.setupEdgeGestureRecognizers()
                    return
                }
            }
            
            let finalCenterX = newX + currentFrame.width / 2
            let targetX: CGFloat = finalCenterX < screenWidth / 2 ? 0 : screenWidth - currentFrame.width
            
            let targetY = max(0, min(screenHeight - currentFrame.height, newY))
            
            if self.isDockHidden {
                self.isDockHidden = false
                self.setupEdgeGestureRecognizers()
            }
            
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.5,
                options: .curveEaseOut
            ) {
                hostingController.view.frame = CGRect(
                    x: targetX,
                    y: targetY,
                    width: currentFrame.width,
                    height: currentFrame.height
                )
            }
        }
    }
    
    func openApp(uuid: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.bringMultitaskViewToFront(uuid: uuid) {
                return
            }
            
            if #available(iOS 16.1, *) {
                if let multitaskWindowManagerClass = NSClassFromString("MultitaskWindowManager") {
                    let selector = NSSelectorFromString("openExistingAppWindowWithDataUUID:")
                    if multitaskWindowManagerClass.responds(to: selector) {
                        let methodImpl = multitaskWindowManagerClass.method(for: selector)
                        typealias FunctionType = @convention(c) (AnyObject, Selector, String) -> Bool
                        let function = unsafeBitCast(methodImpl, to: FunctionType.self)
                        let _ = function(multitaskWindowManagerClass, selector, uuid)
                    }
                }
            }
        }
    }
    
    // Find and bring corresponding multitask view to front
    private func bringMultitaskViewToFront(uuid: String) -> Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return false
        }
        
        for window in windowScene.windows {
            if let targetView = findMultitaskView(in: window, withUUID: uuid) {
                if targetView.isHidden || targetView.alpha < 0.1 {
                    targetView.isHidden = false
                    
                    UIView.animate(withDuration: 0.3, 
                                  delay: 0, 
                                  options: .curveEaseOut,
                                  animations: {
                        targetView.alpha = 1.0
                        targetView.transform = .identity
                    }, completion: { _ in
                        if let superview = targetView.superview {
                            superview.bringSubviewToFront(targetView)
                        }
                    })
                    
                    return true
                }
                
                if let superview = targetView.superview {
                    superview.bringSubviewToFront(targetView)
                    
                    if let windowSuperview = window.superview {
                        windowSuperview.bringSubviewToFront(window)
                    }
                    
                    UIView.animate(withDuration: 0.15, animations: {
                        targetView.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
                    }) { _ in
                        UIView.animate(withDuration: 0.1) {
                            targetView.transform = .identity
                        }
                    }
                    
                    return true
                }
            }
        }
        
        return false
    }
    
    // Recursively find multitask view
    private func findMultitaskView(in view: UIView, withUUID uuid: String) -> UIView? {
        let className = NSStringFromClass(type(of: view))
        
        if className.contains("DecoratedAppSceneView") || className.contains("DecoratedFloatingView") {
            if let dataUUID = getDataUUID(from: view), dataUUID == uuid {
                return view
            }
        }
        
        for subview in view.subviews {
            if let foundView = findMultitaskView(in: subview, withUUID: uuid) {
                return foundView
            }
        }
        
        return nil
    }
    
    // Get view's dataUUID property through reflection
    private func getDataUUID(from view: UIView) -> String? {
        let mirror = Mirror(reflecting: view)
        
        for child in mirror.children {
            if child.label == "dataUUID" {
                return child.value as? String
            }
        }
        
        if view.responds(to: NSSelectorFromString("dataUUID")) {
            return view.value(forKey: "dataUUID") as? String
        }
        
        return nil
    }
    
    @objc public func addRunningAppWithInfo(_ appInfo: LCAppInfo, appUUID: String) {
        guard isDockEnabled() else { return }
        
        let appName = appInfo.displayName() ?? "Unknown App"
        
        if apps.contains(where: { $0.appUUID == appUUID }) {
            return
        }
        
        let appModel = DockAppModel(appName: appName, appUUID: appUUID, appInfo: appInfo)
        
        DispatchQueue.main.async {
            self.apps.append(appModel)
            
            if self.apps.count == 1 {
                self.showDock()
            } else if self.isVisible {
                self.updateDockFrame()
            }
        }
    }
    
    private func findAppInfoByDataUUID(_ dataUUID: String) -> LCAppInfo? {
        guard let appGroupPath = LCUtils.appGroupPath()?.path else {
            return nil
        }
        
        let liveContainerPath = "\(appGroupPath)/LiveContainer"
        let containerPath = "\(liveContainerPath)/Data/Application/\(dataUUID)"
        let lcAppInfoPath = "\(containerPath)/LCAppInfo.plist"
        
        if FileManager.default.fileExists(atPath: lcAppInfoPath),
           let appInfoDict = NSDictionary(contentsOfFile: lcAppInfoPath),
           let bundlePath = appInfoDict["bundlePath"] as? String {
            
            if let appInfo = LCAppInfo(bundlePath: bundlePath) {
                return appInfo
            }
        }
        
        let oldContainerPath = "\(appGroupPath)/Containers/\(dataUUID)"
        let oldLCAppInfoPath = "\(oldContainerPath)/LCAppInfo.plist"
        
        if FileManager.default.fileExists(atPath: oldLCAppInfoPath),
           let appInfoDict = NSDictionary(contentsOfFile: oldLCAppInfoPath),
           let bundlePath = appInfoDict["bundlePath"] as? String {
            
            if let appInfo = LCAppInfo(bundlePath: bundlePath) {
                return appInfo
            }
        }
        
        if let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            let privateContainerPath = "\(docPath)/Data/Application/\(dataUUID)"
            let privateLCAppInfoPath = "\(privateContainerPath)/LCAppInfo.plist"
            
            if FileManager.default.fileExists(atPath: privateLCAppInfoPath),
               let appInfoDict = NSDictionary(contentsOfFile: privateLCAppInfoPath),
               let bundlePath = appInfoDict["bundlePath"] as? String {
                
                if let appInfo = LCAppInfo(bundlePath: bundlePath) {
                    return appInfo
                }
            }
        }
        
        return nil
    }
    
    private func findAppInfoByName(_ appName: String) -> LCAppInfo? {
        var searchPaths: [String] = []
        
        if let appGroupPath = LCUtils.appGroupPath()?.path {
            let sharedAppsPath = "\(appGroupPath)/LiveContainer/Applications"
            searchPaths.append(sharedAppsPath)
        }
        
        if let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            let privateAppsPath = "\(docPath)/Applications"
            searchPaths.append(privateAppsPath)
        }
        
        for appsPath in searchPaths {
            guard FileManager.default.fileExists(atPath: appsPath) else {
                continue
            }
            
            do {
                let appDirs = try FileManager.default.contentsOfDirectory(atPath: appsPath)
                
                for appDir in appDirs {
                    guard appDir.hasSuffix(".app") else { continue }
                    
                    let appBundlePath = "\(appsPath)/\(appDir)"
                    var isDirectory: ObjCBool = false
                    
                    guard FileManager.default.fileExists(atPath: appBundlePath, isDirectory: &isDirectory),
                          isDirectory.boolValue else {
                        continue
                    }
                    
                    if let appInfo = LCAppInfo(bundlePath: appBundlePath) {
                        let displayName = appInfo.displayName()
                        
                        if displayName == appName {
                            return appInfo
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    private func findAppInfoFromSharedModel(appName: String, dataUUID: String) -> LCAppInfo? {
        let sharedModel = DataManager.shared.model
        
        for appModel in sharedModel.apps {
            for container in appModel.appInfo.containers {
                if container.folderName == dataUUID {
                    return appModel.appInfo
                }
            }
        }
        
        for appModel in sharedModel.hiddenApps {
            for container in appModel.appInfo.containers {
                if container.folderName == dataUUID {
                    return appModel.appInfo
                }
            }
        }
        
        for appModel in sharedModel.apps {
            if appModel.appInfo.displayName() == appName {
                return appModel.appInfo
            }
        }
        
        for appModel in sharedModel.hiddenApps {
            if appModel.appInfo.displayName() == appName {
                return appModel.appInfo
            }
        }
        
        return nil
    }
    
    @objc public func toggleDockCollapse() {
        DispatchQueue.main.async {
            self.isCollapsed.toggle()
            self.updateDockFrame()
        }
    }
    
    // 新增：切换dock隐藏状态
    @objc public func toggleDockVisibility() {
        DispatchQueue.main.async {
            self.isDockHidden.toggle()
            self.updateDockFrame()
        }
    }
    
    @objc public func showDockFromHidden() {
        DispatchQueue.main.async {
            self.isDockHidden = false
            self.updateDockFrame()
            self.setupEdgeGestureRecognizers()
        }
    }
    
    @objc public func hideDockToSide() {
        DispatchQueue.main.async {
            self.isDockHidden = true
            self.updateDockFrame()
            self.setupEdgeGestureRecognizers()
        }
    }
    
    // Add edge gesture recognition areas when dock is hidden
    private func setupEdgeGestureRecognizers() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first else { return }
        
        keyWindow.gestureRecognizers?.removeAll { gesture in
            return gesture is UITapGestureRecognizer || gesture is UIScreenEdgePanGestureRecognizer
        }
        
        if isDockHidden {
            let leftEdgeGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgeSwipe(_:)))
            leftEdgeGesture.edges = .left
            keyWindow.addGestureRecognizer(leftEdgeGesture)
            
            let rightEdgeGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgeSwipe(_:)))
            rightEdgeGesture.edges = .right
            keyWindow.addGestureRecognizer(rightEdgeGesture)
        }
    }
    
    @objc private func handleEdgeSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard isDockHidden else { return }
        
        let translation = gesture.translation(in: gesture.view)
        
        switch gesture.state {
        case .began, .changed:
            let swipeDistance = abs(translation.x)
            if swipeDistance > 30 {
                showDockFromHidden()
            }
        default:
            break
        }
    }
    
    // MARK: - Multitask Mode Check
    private func isDockEnabled() -> Bool {
        let multitaskMode = MultitaskMode(rawValue: LCUtils.appGroupUserDefault.integer(forKey: "LCMultitaskMode")) ?? .virtualWindow
        return multitaskMode == .virtualWindow
    }
}

// MARK: - SwiftUI Dock View
public struct MultitaskDockSwiftView: View {
    @EnvironmentObject var dockManager: MultitaskDockManager
    @State private var dragOffset = CGSize.zero
    @State private var showTooltip = false
    @State private var tooltipApp: DockAppModel?
    @State private var dragStartLocation: CGPoint = .zero
    @State private var isDragging = false
    
    // Calculate dynamic padding based on user settings
    private var dynamicPadding: CGFloat {
        let basePadding: CGFloat = 8
        let extraPadding = (dockManager.dockWidth - 90) * 0.2
        return max(basePadding, basePadding + extraPadding)
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            if dockManager.isCollapsed {
                CollapsedDockView(isHidden: dockManager.isDockHidden)
                    .onTapGesture {
                        dockManager.toggleDockCollapse()
                    }
            } else {
                VStack(spacing: 8) {
                    CollapseButtonView()
                        .onTapGesture {
                            dockManager.toggleDockCollapse()
                        }
                    
                    ForEach(dockManager.apps.indices, id: \.self) { index in
                        let app = dockManager.apps[index]
                        AppIconView(app: app, showTooltip: $showTooltip, tooltipApp: $tooltipApp)
                            .onTapGesture {
                                if !isDragging {
                                    dockManager.openApp(uuid: app.appUUID)
                                }
                            }
                    }
                }
            }
        }
        .padding(.vertical, 15)  
        .padding(.horizontal, dynamicPadding)
        .frame(width: dockManager.dockWidth)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(dockManager.isDockHidden ? 0.3 : 0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(dockManager.isDockHidden ? 0.1 : 0.3), lineWidth: 1)
                )
        )
        .scaleEffect(dockManager.isVisible ? 1.0 : 0.8)
        .opacity(dockManager.isDockHidden ? 0.4 : 1.0)
        .offset(dragOffset)
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartLocation = value.startLocation
                    }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    
                    let horizontalDistance = abs(value.translation.width)
                    let verticalDistance = abs(value.translation.height)
                    
                    if horizontalDistance > verticalDistance && horizontalDistance > 60 {
                        let screenWidth = UIScreen.main.bounds.width
                        let currentX = dockManager.hostingController?.view.frame.origin.x ?? 0
                        let isOnRightSide = currentX > screenWidth / 2
                        
                        if (isOnRightSide && value.translation.width > 0) || (!isOnRightSide && value.translation.width < 0) {
                            dockManager.hideDockToSide()
                            
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = .zero
                            }
                            return
                        }
                    }
                    
                    if dockManager.isDockHidden && horizontalDistance > 30 {
                        let screenWidth = UIScreen.main.bounds.width
                        let currentX = dockManager.hostingController?.view.frame.origin.x ?? 0
                        let isOnRightSide = currentX > screenWidth / 2
                        
                        if (isOnRightSide && value.translation.width < 0) || (!isOnRightSide && value.translation.width > 0) {
                            dockManager.showDockFromHidden()
                            
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = .zero
                            }
                            return
                        }
                    }
                    
                    dockManager.updateDockPosition(translation: value.translation)
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
        )
        .overlay(
            Group {
                if showTooltip, let app = tooltipApp {
                    TooltipView(app: app)
                        .transition(.opacity)
                }
            }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dockManager.isCollapsed)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dockManager.isDockHidden)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dockManager.dockWidth)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dockManager.settingsChanged)
    }
    
    public init() {}
}

// MARK: - Collapsed Dock View
struct CollapsedDockView: View {
    let isHidden: Bool
    @EnvironmentObject var dockManager: MultitaskDockManager
    
    // Dynamically adjust collapsed button size based on dock width
    private var buttonSize: CGFloat {
        let minSize: CGFloat = 44
        let maxSize: CGFloat = 80
        let targetSize = dockManager.dockWidth * 0.7
        return max(minSize, min(maxSize, targetSize))
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(isHidden ? 0.4 : 0.8),
                            Color.blue.opacity(isHidden ? 0.3 : 0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: buttonSize, height: buttonSize)
            
            Group {
                if isHidden {
                    Image(systemName: "eye.slash")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: buttonSize * 0.35, weight: .bold))
                } else {
                    Image(systemName: "chevron.up")
                        .foregroundColor(.white)
                        .font(.system(size: buttonSize * 0.4, weight: .bold))
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(isHidden ? 0.2 : 0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
        .scaleEffect(isHidden ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHidden)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: buttonSize)
    }
}

// MARK: - Collapse Button View
struct CollapseButtonView: View {
    @EnvironmentObject var dockManager: MultitaskDockManager
    
    // Dynamically adjust button size based on dock width
    private var buttonSize: CGFloat {
        let minSize: CGFloat = 44
        let maxSize: CGFloat = 80
        let targetSize = dockManager.dockWidth * 0.7
        return max(minSize, min(maxSize, targetSize))
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)  
                .fill(Color.gray.opacity(0.8))
                .frame(width: buttonSize, height: buttonSize)
            
            Image(systemName: "chevron.down")
                .foregroundColor(.white)
                .font(.system(size: buttonSize * 0.4, weight: .semibold))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)  
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: buttonSize)
    }
}

// MARK: - Icon Cache Manager
class IconCacheManager {
    static let shared = IconCacheManager()
    private var cache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "icon.cache.queue", attributes: .concurrent)
    
    private init() {}
    
    func getIcon(for key: String) -> UIImage? {
        return cacheQueue.sync {
            return cache[key]
        }
    }
    
    func setIcon(_ icon: UIImage, for key: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = icon
        }
    }
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

// MARK: - App Icon View
struct AppIconView: View {
    let app: DockAppModel
    @Binding var showTooltip: Bool
    @Binding var tooltipApp: DockAppModel?
    @State private var isPressed = false
    @State private var appIcon: UIImage?
    @State private var isLoading = true
    @EnvironmentObject var dockManager: MultitaskDockManager
    
    private var iconSize: CGFloat {
        return dockManager.adaptiveIconSize
    }
    
    var body: some View {
        Group {
            if isLoading && appIcon == nil {
                LoadingIconView()
            } else if let icon = appIcon {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                PlaceholderIconView(appName: app.appName)
            }
        }
        .frame(width: iconSize, height: iconSize)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 3)
        .scaleEffect(isPressed ? 1.15 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .animation(.easeInOut(duration: 0.3), value: dockManager.settingsChanged)
        .onAppear {
            loadAppIcon()
        }
        .onPressGesture(
            onPress: { 
                isPressed = true
            },
            onRelease: { 
                isPressed = false
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        )
        .contentShape(Rectangle())
    }
    
    private func loadAppIcon() {
        let cacheKey = "\(app.appName)_\(app.appUUID)"
        
        if let cachedIcon = IconCacheManager.shared.getIcon(for: cacheKey) {
            self.appIcon = cachedIcon
            self.isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var icon: UIImage?
            
            if let appInfo = self.app.appInfo {
                icon = appInfo.icon()
                if icon != nil {
                    NSLog("[Dock] Found icon via passed appInfo for app: \(self.app.appName)")
                }
            } else {
                icon = self.loadIconForApp()
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
                if let icon = icon {
                    self.appIcon = icon
                    IconCacheManager.shared.setIcon(icon, for: cacheKey)
                    NSLog("[Dock] Successfully loaded and cached icon for app: \(self.app.appName)")
                } else {
                    NSLog("[Dock] Failed to load icon for app: \(self.app.appName) with UUID: \(self.app.appUUID)")
                }
            }
        }
    }
    
    private func loadIconForApp() -> UIImage? {
        NSLog("[Dock] Attempting to load icon for app: \(app.appName) with UUID: \(app.appUUID)")
        
        if let appInfo = findAppInfoByDataUUID() {
            NSLog("[Dock] Found appInfo via dataUUID for app: \(app.appName)")
            return appInfo.icon()
        }
        
        if let appInfo = findAppInfoByName() {
            NSLog("[Dock] Found appInfo via name for app: \(app.appName)")
            return appInfo.icon()
        }
        
        NSLog("[Dock] Could not find appInfo for app: \(app.appName) with UUID: \(app.appUUID)")
        return nil
    }
    
    private func findAppInfoByDataUUID() -> LCAppInfo? {
        guard let appGroupPath = LCUtils.appGroupPath()?.path else {
            return nil
        }
        
        let liveContainerPath = "\(appGroupPath)/LiveContainer"
        let containerPath = "\(liveContainerPath)/Data/Application/\(app.appUUID)"
        let lcAppInfoPath = "\(containerPath)/LCAppInfo.plist"
        
        if FileManager.default.fileExists(atPath: lcAppInfoPath),
           let appInfoDict = NSDictionary(contentsOfFile: lcAppInfoPath),
           let bundlePath = appInfoDict["bundlePath"] as? String {
            
            if let appInfo = LCAppInfo(bundlePath: bundlePath) {
                return appInfo
            }
        }
        
        let oldContainerPath = "\(appGroupPath)/Containers/\(app.appUUID)"
        let oldLCAppInfoPath = "\(oldContainerPath)/LCAppInfo.plist"
        
        if FileManager.default.fileExists(atPath: oldLCAppInfoPath),
           let appInfoDict = NSDictionary(contentsOfFile: oldLCAppInfoPath),
           let bundlePath = appInfoDict["bundlePath"] as? String {
            
            if let appInfo = LCAppInfo(bundlePath: bundlePath) {
                return appInfo
            }
        }
        
        if let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            let privateContainerPath = "\(docPath)/Data/Application/\(app.appUUID)"
            let privateLCAppInfoPath = "\(privateContainerPath)/LCAppInfo.plist"
            
            if FileManager.default.fileExists(atPath: privateLCAppInfoPath),
               let appInfoDict = NSDictionary(contentsOfFile: privateLCAppInfoPath),
               let bundlePath = appInfoDict["bundlePath"] as? String {
                
                if let appInfo = LCAppInfo(bundlePath: bundlePath) {
                    return appInfo
                }
            }
        }
        
        return nil
    }
    
    private func findAppInfoByName() -> LCAppInfo? {
        var searchPaths: [String] = []
        
        if let appGroupPath = LCUtils.appGroupPath()?.path {
            let sharedAppsPath = "\(appGroupPath)/LiveContainer/Applications"
            searchPaths.append(sharedAppsPath)
        }
        
        if let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            let privateAppsPath = "\(docPath)/Applications"
            searchPaths.append(privateAppsPath)
        }
        
        for appsPath in searchPaths {
            guard FileManager.default.fileExists(atPath: appsPath) else {
                continue
            }
            
            do {
                let appDirs = try FileManager.default.contentsOfDirectory(atPath: appsPath)
                
                for appDir in appDirs {
                    guard appDir.hasSuffix(".app") else { continue }
                    
                    let appBundlePath = "\(appsPath)/\(appDir)"
                    var isDirectory: ObjCBool = false
                    
                    guard FileManager.default.fileExists(atPath: appBundlePath, isDirectory: &isDirectory),
                          isDirectory.boolValue else {
                        continue
                    }
                    
                    if let appInfo = LCAppInfo(bundlePath: appBundlePath) {
                        let displayName = appInfo.displayName()
                        
                        if displayName == app.appName {
                            return appInfo
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
}

// MARK: - Placeholder Icon View
struct PlaceholderIconView: View {
    let appName: String
    
    private var backgroundColor: Color {
        let hash = abs(appName.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    private var gradientColors: [Color] {
        let baseColor = backgroundColor
        return [
            baseColor,
            baseColor.opacity(0.8)
        ]
    }
    
    private var initials: String {
        let words = appName.components(separatedBy: .whitespaces)
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if appName.count >= 2 {
            return String(appName.prefix(2)).uppercased()
        } else {
            return String(appName.prefix(1)).uppercased() + "?"
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.3), location: 0),
                            .init(color: Color.clear, location: 0.3),
                            .init(color: Color.clear, location: 0.7),
                            .init(color: Color.black.opacity(0.1), location: 1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(initials)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Tooltip View
struct TooltipView: View {
    let app: DockAppModel
    
    var body: some View {
        VStack(spacing: 4) {
            Text(app.appName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            
            Text(String(app.appUUID.prefix(8)))
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
        )
        .offset(x: -60, y: 0)
    }
}

// MARK: - Press Gesture Helper
extension View {
    func onPressGesture(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if value.translation == CGSize.zero {
                        onPress()
                    }
                }
                .onEnded { _ in 
                    onRelease() 
                }
        )
    }
}

// MARK: - Loading Icon View
struct LoadingIconView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
            
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 20, height: 20)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Hidden Dock Indicator View
struct HiddenDockIndicatorView: View {
    let isOnRightSide: Bool
    @State private var isPulsing = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.8),
                        Color.white.opacity(0.6)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4, height: 30)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.8 : 0.5)
            .animation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}
