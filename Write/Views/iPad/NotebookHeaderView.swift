import UIKit

@MainActor
final class NotebookHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "NotebookHeaderView"

    private let kanjiLabel = UILabel()
    private let readingsLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        let stack = UIStackView(arrangedSubviews: [kanjiLabel, readingsLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4)
        ])

        kanjiLabel.font = .systemFont(ofSize: 44)
        kanjiLabel.textAlignment = .center

        readingsLabel.font = .systemFont(ofSize: 13)
        readingsLabel.textColor = .secondaryLabel
        readingsLabel.textAlignment = .center
        readingsLabel.numberOfLines = 3
        readingsLabel.adjustsFontSizeToFitWidth = true
        readingsLabel.minimumScaleFactor = 0.7
    }

    func configure(with kanji: KanjiData) {
        kanjiLabel.text = String(kanji.character)

        var parts: [String] = []
        if let on = kanji.onYomi, !on.isEmpty {
            parts.append(on.joined(separator: "、"))
        }
        if let kun = kanji.kunYomi, !kun.isEmpty {
            parts.append(kun.joined(separator: "、"))
        }
        readingsLabel.text = parts.joined(separator: "\n")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        kanjiLabel.text = nil
        readingsLabel.text = nil
    }
}
