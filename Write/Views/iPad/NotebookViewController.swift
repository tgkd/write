import UIKit

@MainActor
final class NotebookViewController: UIViewController {

    var notebookState: NotebookState? {
        didSet { reloadIfNeeded() }
    }

    var showCrosshair: Bool = true
    var allowedTouchTypes: Set<UITouch.TouchType> = [.direct, .pencil]
    var pressureSensitivity: PressureSensitivity = .off

    var sourceKanji: [KanjiData] = []

    private var collectionView: UICollectionView!
    private var didFillRows = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupCollectionView()
        navigationItem.hidesBackButton = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(showTips)
        )
    }

    private let tipsOverlay = NotebookTipsOverlay()

    @objc private func showTips() {
        guard let state = notebookState, !state.rows.isEmpty else { return }

        var tips: [NotebookTip] = []

        let refIndexPath = IndexPath(item: 0, section: 0)
        if let refCell = collectionView.cellForItem(at: refIndexPath) {
            let rect = refCell.convert(refCell.bounds, to: view)
            tips.append(NotebookTip(
                text: "Tap the reference kanji to see stroke order animation",
                sourceRect: rect,
                arrowDirection: .up
            ))
        }

        let practiceIndexPath = IndexPath(item: 1, section: 0)
        if let practiceCell = collectionView.cellForItem(at: practiceIndexPath) {
            let rect = practiceCell.convert(practiceCell.bounds, to: view)
            tips.append(NotebookTip(
                text: "Draw in any cell to practice — no rules, just write",
                sourceRect: rect,
                arrowDirection: .up
            ))
        }

        let lastPracticeIndexPath = IndexPath(item: 2, section: 0)
        if let cell = collectionView.cellForItem(at: lastPracticeIndexPath) {
            let rect = cell.convert(cell.bounds, to: view)
            tips.append(NotebookTip(
                text: "Double-tap a cell to clear it and start over",
                sourceRect: rect,
                arrowDirection: .up
            ))
        }

        if let barButton = navigationItem.rightBarButtonItem,
           let barView = barButton.value(forKey: "view") as? UIView {
            let rect = barView.convert(barView.bounds, to: view)
            tips.append(NotebookTip(
                text: "Use the sidebar to pick a different kanji",
                sourceRect: rect,
                arrowDirection: .up
            ))
        }

        tipsOverlay.show(tips: tips, in: view) {}
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fillRowsIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }

    // MARK: - Setup

    private func setupCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.register(NotebookCellView.self, forCellWithReuseIdentifier: NotebookCellView.reuseIdentifier)
        view.addSubview(collectionView)
    }

    // MARK: - Layout

    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            self?.createSectionLayout(environment: environment)
        }
    }

    private func createSectionLayout(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let totalColumns = (notebookState?.cellsPerRow ?? 8) + 1
        let containerWidth = environment.container.effectiveContentSize.width
        let cellWidth = containerWidth / CGFloat(totalColumns)

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(cellWidth),
            heightDimension: .absolute(cellWidth)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(cellWidth)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        return section
    }

    // MARK: - Fill Rows

    private func fillRowsIfNeeded() {
        guard !didFillRows, let state = notebookState, !sourceKanji.isEmpty else { return }
        didFillRows = true

        let totalColumns = state.cellsPerRow + 1
        let containerWidth = view.bounds.width
        let cellSize = containerWidth / CGFloat(totalColumns)
        guard cellSize > 0 else { return }

        let navBarHeight = navigationController?.navigationBar.frame.maxY ?? 0
        let availableHeight = view.bounds.height - navBarHeight
        let rowCount = max(1, Int(floor(availableHeight / cellSize)))

        let currentCount = state.rows.count
        if rowCount > currentCount {
            var kanjiIndex = currentCount % sourceKanji.count
            for _ in currentCount..<rowCount {
                state.addRow(kanji: sourceKanji[kanjiIndex])
                kanjiIndex = (kanjiIndex + 1) % sourceKanji.count
            }
            collectionView.reloadData()
        }
    }

    // MARK: - Reload

    private func reloadIfNeeded() {
        guard isViewLoaded else { return }
        collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource

extension NotebookViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        notebookState?.rows.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let state = notebookState else { return 0 }
        return state.rows[section].cellCount + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: NotebookCellView.reuseIdentifier,
            for: indexPath
        ) as! NotebookCellView

        guard let state = notebookState else { return cell }

        if indexPath.item == 0 {
            cell.configureReference(kanji: state.rows[indexPath.section].kanjiData)
            return cell
        }

        cell.configurePractice(
            showCrosshair: showCrosshair,
            allowedTouchTypes: allowedTouchTypes,
            pressureSensitivity: pressureSensitivity
        )
        return cell
    }
}
