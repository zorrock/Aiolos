//
//  PanelViewController.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// A floating Panel inspired by the iOS 11 Maps.app UI
public final class PanelViewController: UIViewController {

    private lazy var panelView: PanelView = self.makePanelView()
    private var containerView: ContainerView? { return self.viewIfLoaded as? ContainerView }
    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!
    private var positionConstraints: [NSLayoutConstraint] = []

    // MARK: - Properties

    public var isVisible: Bool { return self.parent != nil }
    public weak var sizeDelegate: PanelSizeDelegate?
    public weak var animationDelegate: PanelAnimationDelegate?

    public var configuration: Panel.Configuration {
        didSet {
            self.handleConfigurationChange(from: oldValue, to: self.configuration)
        }
    }

    public var contentViewController: UIViewController? {
        didSet {
            self.updateContentViewControllerFrame(of: self.contentViewController)
            self.exchangeContentViewController(oldValue, with: self.contentViewController)
        }
    }

    // MARK: - Lifecycle

    public init(configuration: Panel.Configuration = .default) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UIViewController

public extension PanelViewController {

    override func loadView() {
        self.view = self.makeContainer(for: self.panelView)

        // setup layout constraints
        let size = self.size(for: self.configuration.mode)

        self.widthConstraint = self.view.widthAnchor.constraint(equalToConstant: size.width).configure { c in
            c.identifier = "Panel Width"
            c.priority = .defaultHigh
        }
        self.heightConstraint = self.view.heightAnchor.constraint(equalToConstant: size.height).configure { c in
            c.identifier = "Panel Height"
            c.priority = .defaultHigh
        }
        NSLayoutConstraint.activate([self.widthConstraint, self.heightConstraint])
    }
}

// MARK: - PanelViewController

public extension PanelViewController {

    func add(to parent: UIViewController) {
        parent.addChildViewController(self)
        parent.view.addSubview(self.view)
        self.didMove(toParentViewController: parent)

        self.updatePositionConstraints(for: self.configuration.position, margins: self.configuration.margins)
    }

    func removeFromParent() {
        guard self.parent != nil else { return }

        self.willMove(toParentViewController: nil)
        self.view.removeFromSuperview()
        self.removeFromParentViewController()

        self.view.removeConstraints(self.positionConstraints)
        self.positionConstraints = []
    }
}

// MARK: - Private

private extension PanelViewController {

    func makePanelView() -> PanelView {
        return PanelView(configuration: self.configuration)
    }

    func makeContainer(for view: UIView) -> UIView {
        let container = ContainerView(configuration: self.configuration)

        // create view hierachy
        view.frame = container.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(view)
        container.translatesAutoresizingMaskIntoConstraints = false

        return container
    }

    func updateContentViewControllerFrame(of contentViewController: UIViewController?) {
        guard let contentViewController = contentViewController else { return }

        contentViewController.view.frame = self.panelView.contentView.bounds
        contentViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    func exchangeContentViewController(_ oldContentViewController: UIViewController?, with newContentViewController: UIViewController?) {
        // remove old contentViewController
        if let oldContentViewController = oldContentViewController {
            oldContentViewController.willMove(toParentViewController: nil)
            oldContentViewController.view.removeFromSuperview()
            oldContentViewController.removeFromParentViewController()
        }

        // add new contentViewController
        if let newContentViewController = newContentViewController {
            self.addChildViewController(newContentViewController)
            self.panelView.contentView.addSubview(newContentViewController.view)
            newContentViewController.didMove(toParentViewController: self)
        }
    }

    func handleConfigurationChange(from oldConfiguration: Panel.Configuration, to newConfiguration: Panel.Configuration) {
        self.panelView.configure(with: newConfiguration)
        self.containerView?.configure(with: newConfiguration)

        if oldConfiguration.mode != newConfiguration.mode {
            self.updateModeConstraints(for: newConfiguration.mode)
        }

        if oldConfiguration.position != newConfiguration.position {
            self.updatePositionConstraints(for: newConfiguration.position, margins: newConfiguration.margins)
        }
    }

    func size(for mode: Panel.Configuration.Mode) -> CGSize {
        guard let sizeDelegate = self.sizeDelegate else { return .zero }
        guard let parent = self.parent else { return .zero }

        let delegateSize = sizeDelegate.panel(self, sizeForMode: mode)
        let maxSize = parent.view.bounds.insetBy(parent.view.safeAreaInsets).size

        let width = parent.traitCollection.userInterfaceIdiom == .pad ? 320.0 : parent.view.frame.width

        switch mode {
        case .collapsed:
            return CGSize(width: width, height: 64.0)
        case .expanded:
            return CGSize(width: width, height: 250.0)
        case .fullHeight:
            return CGSize(width: width, height: maxSize.height)
        }
    }

    func updateModeConstraints(for mode: Panel.Configuration.Mode) {
        assert(self.widthConstraint != nil)
        assert(self.heightConstraint != nil)

        let size = self.size(for: mode)
        self.widthConstraint.constant = size.width
        self.heightConstraint.constant = size.height
    }

    func updatePositionConstraints(for position: Panel.Configuration.Position, margins: UIEdgeInsets) {
        guard let parentView = self.parent?.view else { return }

        self.view.removeConstraints(self.positionConstraints)

        let guide = parentView.safeAreaLayoutGuide
        var positionConstraints = [
            self.view.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -margins.bottom).withIdentifier("Panel Bottom"),
            self.view.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor, constant: margins.top).withIdentifier("Panel Top")
        ]

        switch position {
        case .bottom:
            positionConstraints += [
                self.view.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margins.left).withIdentifier("Panel Leading"),
                self.view.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -margins.right).withIdentifier("Panel Trailing")
            ]

        case .leadingBottom:
            positionConstraints += [
                self.view.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margins.left).withIdentifier("Panel Leading")
            ]

        case .trailingBottom:
            positionConstraints += [
                self.view.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -margins.right).withIdentifier("Panel Trailing")
            ]
        }

        self.positionConstraints = positionConstraints
        NSLayoutConstraint.activate(self.positionConstraints)
    }
}

// MARK: - NSLayoutConstraint

private extension NSLayoutConstraint {

    func configure(_ configuration: (NSLayoutConstraint) -> Void) -> NSLayoutConstraint {
        configuration(self)
        return self
    }

    func withIdentifier(_ identifier: String) -> NSLayoutConstraint {
        return self.configure { c in
            c.identifier = identifier
        }
    }
}

// MARK: - CGRect

private extension CGRect {

    func insetBy(_ edgeInsets: UIEdgeInsets) -> CGRect {
        return UIEdgeInsetsInsetRect(self, edgeInsets)
    }
}
