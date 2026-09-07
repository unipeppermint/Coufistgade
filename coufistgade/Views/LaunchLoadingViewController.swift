import UIKit

final class LaunchLoadingViewController: UIViewController {

    private let onAppear: (() -> Void)?
    private let spinner = UIActivityIndicatorView(style: .large)
    private let titleLabel = UILabel()
    private let stack = UIStackView()

    init(onAppear: (() -> Void)? = nil) {
        self.onAppear = onAppear
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LaunchLoadingViewController is code-only; this app uses no storyboards or nibs.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(resource: .appBackground)

        spinner.color = UIColor(resource: .textPrimary)
        spinner.startAnimating()

        titleLabel.text = Strings.loading
        titleLabel.font = Theme.Typography.rounded(
            .headline,
            weight: .semibold,
            maximumPointSize: Theme.Typography.MaxPointSize.buttonLabel
        )
        titleLabel.textColor = UIColor(resource: .textSecondary)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Theme.Spacing.s
        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: Theme.Spacing.m),
            view.trailingAnchor.constraint(greaterThanOrEqualTo: stack.trailingAnchor, constant: Theme.Spacing.m),
        ])

        view.isAccessibilityElement = true
        view.accessibilityLabel = Strings.loading
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onAppear?()
    }
}
