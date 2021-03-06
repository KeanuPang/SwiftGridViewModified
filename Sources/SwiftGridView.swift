// SwiftGridView.swift
// Copyright (c) 2016 - Present Nathan Lampi (http://nathanlampi.com/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import UIKit

public let SwiftGridElementKindHeader: String = "SwiftGridElementKindHeader"
public let SwiftGridElementKindGroupedHeader: String = "SwiftGridElementKindGroupedHeader"
public let SwiftGridElementKindSectionHeader: String = UICollectionView.elementKindSectionHeader
public let SwiftGridElementKindFooter: String = "SwiftGridElementKindFooter"
public let SwiftGridElementKindSectionFooter: String = UICollectionView.elementKindSectionFooter

// MARK: - SwiftGridView Class

/**
 `SwiftGridView` is the primary view class, utilizing a UICollectionView and a custom layout handler.
 */
open class SwiftGridView: UIView, UICollectionViewDataSource, UICollectionViewDelegate, SwiftGridLayoutDelegate, SwiftGridReusableViewDelegate {
    // MARK: Init

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.initDefaults()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.initDefaults()
    }

    fileprivate func initDefaults() {
        self.sgCollectionViewLayout = SwiftGridLayout()

        // FIXME: Use constraints!?
        self.collectionView = UICollectionView(frame: self.bounds, collectionViewLayout: self.sgCollectionViewLayout)
        self.collectionView.dataSource = self // TODO: Separate DataSource/Delegate?
        self.collectionView.delegate = self
        self.collectionView.backgroundColor = self.backgroundColor
        self.collectionView.allowsMultipleSelection = true

        self.addSubview(self.collectionView)
    }

    // MARK: Public Variables

    /**
     Internal Collectionview. Open to allow for custom interaction, modify at own risk.
     */
    @objc open internal(set) var collectionView: UICollectionView!

    #if TARGET_INTERFACE_BUILDER /// Allows IBOutlets to work properly.
    @IBOutlet open weak var dataSource: AnyObject?
    @IBOutlet open weak var delegate: AnyObject?
    #else
    @objc open weak var dataSource: SwiftGridViewDataSource?
    @objc open weak var delegate: SwiftGridViewDelegate?
    #endif

    open var allowsSelection: Bool {
        set(allowsSelection) {
            self.collectionView.allowsSelection = allowsSelection
        }
        get {
            return self.collectionView.allowsSelection
        }
    }

    /**
     When enabled, multiple cells can be selected. If row selection is enabled, then multiple rows can be selected.
     */
    open var allowsMultipleSelection: Bool = false

    /**
     If row selection is enabled, then entire rows will be selected rather than individual cells. This applies to section headers/footers in addition to rows.
     */
    open var rowSelectionEnabled: Bool = true

    /**
     When enabled, the entire row and all cells of column from the selected cell will be selected
     */
    private var crossSelectionEnabled: Bool = false

    /**
     When enabled, then entire rows will not be selected by touch gesture from user
     */
    open var userTouchCellEnabled: Bool = true

    open var isDirectionalLockEnabled: Bool {
        set(isDirectionalLockEnabled) {
            self.collectionView.isDirectionalLockEnabled = isDirectionalLockEnabled
        }
        get {
            return self.collectionView.isDirectionalLockEnabled
        }
    }

    open var bounces: Bool {
        set(bounces) {
            self.collectionView.bounces = bounces
        }
        get {
            return self.collectionView.bounces
        }
    }

    /// Determines whether section headers will stick while scrolling vertically or scroll off screen.
    open var stickySectionHeaders: Bool {
        set(stickySectionHeaders) {
            self.sgCollectionViewLayout.stickySectionHeaders = stickySectionHeaders
        }
        get {
            return self.sgCollectionViewLayout.stickySectionHeaders
        }
    }

    open var alwaysBounceVertical: Bool {
        set(alwaysBounceVertical) {
            self.collectionView.alwaysBounceVertical = alwaysBounceVertical
        }
        get {
            return self.collectionView.alwaysBounceVertical
        }
    }

    open var alwaysBounceHorizontal: Bool {
        set(alwaysBounceHorizontal) {
            self.collectionView.alwaysBounceHorizontal = alwaysBounceHorizontal
        }
        get {
            return self.collectionView.alwaysBounceHorizontal
        }
    }

    /*
     A Boolean value that controls whether the horizontal scroll indicator is visible.
     The default value is true. The indicator is visible while tracking is underway and fades out after tracking.
     */
    open var showsHorizontalScrollIndicator: Bool {
        set(showsHorizontalScrollIndicator) {
            self.collectionView.showsHorizontalScrollIndicator = showsHorizontalScrollIndicator
        }
        get {
            return self.collectionView.showsHorizontalScrollIndicator
        }
    }

    /*
     A Boolean value that controls whether the vertical scroll indicator is visible.
     The default value is true. The indicator is visible while tracking is underway and fades out after tracking.
     */
    open var showsVerticalScrollIndicator: Bool {
        set(showsVerticalScrollIndicator) {
            self.collectionView.showsVerticalScrollIndicator = showsVerticalScrollIndicator
        }
        get {
            return self.collectionView.showsVerticalScrollIndicator
        }
    }

    /// Pinch to expand increases the size of the columns. Experimental feature.
    open var pinchExpandEnabled: Bool = false {
        didSet {
            if !self.pinchExpandEnabled {
                self.collectionView.removeGestureRecognizer(self.sgPinchGestureRecognizer)
                self.collectionView.removeGestureRecognizer(self.sgTwoTapGestureRecognizer)
            } else {
                self.collectionView.addGestureRecognizer(self.sgPinchGestureRecognizer)
                self.sgTwoTapGestureRecognizer.numberOfTouchesRequired = 2
                self.collectionView.addGestureRecognizer(self.sgTwoTapGestureRecognizer)
            }
        }
    }

    /// returns YES if user has touched. may not yet have started draggin
    open var isTracking: Bool {
        return self.collectionView.isTracking
    }

    /// returns YES if user has started scrolling. this may require some time and or distance to move to initiate dragging
    open var isDragging: Bool {
        return self.collectionView.isDragging
    }

    /// returns YES if user isn't dragging (touch up) but scroll view is still moving
    open var isDecelerating: Bool {
        return self.collectionView.isDecelerating
    }

    /// default is YES.
    open var scrollsToTop: Bool {
        set(scrollsToTop) {
            self.collectionView.scrollsToTop = scrollsToTop
        }
        get {
            return self.collectionView.scrollsToTop
        }
    }

    @available(iOS 10.0, *)
    open var refreshControl: UIRefreshControl? {
        set(refreshControl) {
            self.collectionView.refreshControl = refreshControl
        }
        get {
            return self.collectionView.refreshControl
        }
    }

    // MARK: Private Variables

    fileprivate var sgCollectionViewLayout: SwiftGridLayout!
    fileprivate lazy var sgPinchGestureRecognizer: UIPinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(SwiftGridView.handlePinchGesture(_:)))
    fileprivate lazy var sgTwoTapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SwiftGridView.handleTwoFingerTapGesture(_:)))

    fileprivate var _sgSectionCount: Int = 0
    fileprivate var sgSectionCount: Int {
        if _sgSectionCount == 0 {
            _sgSectionCount = self.dataSource!.numberOfSectionsInDataGridView(self)
        }

        return _sgSectionCount
    }

    fileprivate var _sgColumnCount: Int = 0
    fileprivate var sgColumnCount: Int {
        if _sgColumnCount == 0 {
            _sgColumnCount = self.dataSource!.numberOfColumnsInDataGridView(self)
        }

        return _sgColumnCount
    }

    fileprivate var _sgColumnWidth: CGFloat = 0
    fileprivate var sgColumnWidth: CGFloat {
        if _sgColumnWidth == 0 {
            for columnIndex in 0..<self.sgColumnCount {
                _sgColumnWidth += self.delegate!.dataGridView(self, widthOfColumnAtIndex: columnIndex)
            }
        }

        return _sgColumnWidth
    }

    fileprivate var _groupedColumns: [[Int]]?
    fileprivate var groupedColumns: [[Int]] {
        if _groupedColumns == nil {
            if let groupedColumns = self.dataSource?.columnGroupingsForDataGridView?(self) {
                _groupedColumns = groupedColumns
            } else {
                _groupedColumns = [[Int]]()
            }
        }

        return _groupedColumns!
    }

    // Cache selected items.
    fileprivate var selectedHeaders: NSMutableDictionary = NSMutableDictionary()
    fileprivate var selectedGroupedHeaders: NSMutableDictionary = NSMutableDictionary()
    fileprivate var selectedSectionHeaders: NSMutableDictionary = NSMutableDictionary()
    fileprivate var selectedSectionFooters: NSMutableDictionary = NSMutableDictionary()
    fileprivate var selectedFooters: NSMutableDictionary = NSMutableDictionary()

    // MARK: Layout Subviews

    // TODO: Is this how resize should be handled?
    open override func layoutSubviews() {
        super.layoutSubviews()

        if self.collectionView.frame != self.bounds {
            self.collectionView.frame = self.bounds
        }
    }

    // MARK: Public Methods

    open func reloadData() {
        _sgSectionCount = 0
        _sgColumnCount = 0
        _sgColumnWidth = 0
        _groupedColumns = nil

        self.selectedHeaders = NSMutableDictionary()
        self.selectedGroupedHeaders = NSMutableDictionary()
        self.selectedSectionHeaders = NSMutableDictionary()
        self.selectedSectionFooters = NSMutableDictionary()
        self.selectedFooters = NSMutableDictionary()

        sgCollectionViewLayout.resetCachedParameters()

        self.collectionView.reloadData()

        // Adjust offset to not overflow content area based on viewsize
        var contentOffset = self.collectionView.contentOffset
        if self.sgCollectionViewLayout.collectionViewContentSize.height - contentOffset.y < self.collectionView.frame.size.height {
            contentOffset.y = self.sgCollectionViewLayout.collectionViewContentSize.height - self.collectionView.frame.size.height

            if contentOffset.y < 0 {
                contentOffset.y = 0
            }

            self.collectionView.setContentOffset(contentOffset, animated: false)
        }
    }

    open func reloadDataOnly() {
        sgCollectionViewLayout.resetCachedParameters()

        self.collectionView.reloadData()

        // Adjust offset to not overflow content area based on viewsize
        var contentOffset = self.collectionView.contentOffset
        if self.sgCollectionViewLayout.collectionViewContentSize.height - contentOffset.y < self.collectionView.frame.size.height {
            contentOffset.y = self.sgCollectionViewLayout.collectionViewContentSize.height - self.collectionView.frame.size.height

            if contentOffset.y < 0 {
                contentOffset.y = 0
            }

            self.collectionView.setContentOffset(contentOffset, animated: false)
        }
    }

    open func reloadCellsAtIndexPaths(_ indexPaths: [IndexPath], animated: Bool) {
        self.reloadCellsAtIndexPaths(indexPaths, animated: animated, completion: nil)
    }

    open func reloadCellsAtIndexPaths(_ indexPaths: [IndexPath], animated: Bool, completion: ((Bool) -> Void)?) {
        let convertedPaths = self.reverseIndexPathConversionForIndexPaths(indexPaths)

        if animated {
            self.collectionView.performBatchUpdates({
                self.collectionView.reloadItems(at: convertedPaths)
            }, completion: { completed in
                completion?(completed)
            })
        } else {
            self.collectionView.reloadItems(at: convertedPaths)
            completion?(true) // TODO: Fix!
        }
    }

    open func indexPathForItem(at point: CGPoint) -> IndexPath? {
        if let cvIndexPath: IndexPath = self.collectionView.indexPathForItem(at: point) {
            let convertedPath: IndexPath = self.convertCVIndexPathToSGIndexPath(cvIndexPath)

            return convertedPath
        }
        // Look at nearest path?
        return nil
    }

    open func indexPath(for cell: SwiftGridCell) -> IndexPath? {
        if let cvIndexPath: IndexPath = self.collectionView.indexPath(for: cell) {
            let convertedPath: IndexPath = self.convertCVIndexPathToSGIndexPath(cvIndexPath)

            return convertedPath
        }

        return nil
    }

    open func headerForItem(at indexPath: IndexPath) -> SwiftGridReusableView? {
        let revertedPath: IndexPath = self.reverseIndexPathConversion(indexPath)

        let headerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindHeader, at: revertedPath) as? SwiftGridReusableView
        return headerView
    }

    open func groupingHeaderForItem(at indexPath: IndexPath) -> SwiftGridReusableView? {
        let revertedPath: IndexPath = self.reverseIndexPathConversion(indexPath)

        let headerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindGroupedHeader, at: revertedPath) as? SwiftGridReusableView
        return headerView
    }

    open func cellForItem(at indexPath: IndexPath) -> SwiftGridCell? {
        let revertedPath: IndexPath = self.reverseIndexPathConversion(indexPath)
        let cell = self.collectionView.cellForItem(at: revertedPath) as? SwiftGridCell

        return cell
    }

    open var visibleCells: [SwiftGridCell] {
        let cells = self.collectionView.visibleCells as! [SwiftGridCell]

        return cells
    }

    open var indexPathsForVisibleItems: [IndexPath] {
        var indexPaths = [IndexPath]()
        for indexPath in self.collectionView.indexPathsForVisibleItems {
            let convertedPath = self.convertCVIndexPathToSGIndexPath(indexPath)
            indexPaths.append(convertedPath)
        }

        return indexPaths
    }

    // FIXME: Doesn't work as intended.
//    public func reloadSupplementaryViewsOfKind(elementKind: String, atIndexPaths indexPaths: [NSIndexPath]) {
//        let convertedPaths = self.reverseIndexPathConversionForIndexPaths(indexPaths)
//        let context = UICollectionViewLayoutInvalidationContext()
//        context.invalidateSupplementaryElementsOfKind(elementKind, atIndexPaths: convertedPaths)
//
//        self.sgCollectionViewLayout.invalidateLayoutWithContext(context)
//    }

    @objc(registerClass:forCellReuseIdentifier:)
    open func register(_ cellClass: Swift.AnyClass?, forCellWithReuseIdentifier identifier: String) {
        self.collectionView.register(cellClass, forCellWithReuseIdentifier: identifier)
    }

    open func register(_ nib: UINib?, forCellWithReuseIdentifier identifier: String) {
        self.collectionView.register(nib, forCellWithReuseIdentifier: identifier)
    }

    @objc(registerClass:forSupplementaryViewOfKind:withReuseIdentifier:)
    open func register(_ viewClass: Swift.AnyClass?, forSupplementaryViewOfKind elementKind: String, withReuseIdentifier identifier: String) {
        self.collectionView.register(viewClass, forSupplementaryViewOfKind: elementKind, withReuseIdentifier: identifier)
    }

    open func register(_ nib: UINib?, forSupplementaryViewOfKind kind: String, withReuseIdentifier identifier: String) {
        self.collectionView.register(nib, forSupplementaryViewOfKind: kind, withReuseIdentifier: identifier)
    }

    open func dequeueReusableCellWithReuseIdentifier(_ identifier: String, forIndexPath indexPath: IndexPath!) -> SwiftGridCell {
        let revertedPath: IndexPath = self.reverseIndexPathConversion(indexPath)

        return self.collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: revertedPath) as! SwiftGridCell
    }

    open func dequeueReusableSupplementaryViewOfKind(_ elementKind: String, withReuseIdentifier identifier: String, atColumn column: NSInteger) -> SwiftGridReusableView {
        let revertedPath: IndexPath = IndexPath(item: column, section: 0)

        return self.collectionView.dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: identifier, for: revertedPath) as! SwiftGridReusableView
    }

    open func dequeueReusableSupplementaryViewOfKind(_ elementKind: String, withReuseIdentifier identifier: String, forIndexPath indexPath: IndexPath) -> SwiftGridReusableView {
        let revertedPath: IndexPath = self.reverseIndexPathConversion(indexPath)

        return self.collectionView.dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: identifier, for: revertedPath) as! SwiftGridReusableView
    }

    open func selectCellAtIndexPath(_ indexPath: IndexPath, animated: Bool) {
        guard let frozenCount = self.dataSource?.numberOfFrozenColumnsInDataGridView?(self) else { return }

        let convertedPath = self.reverseIndexPathConversion(indexPath)
        if convertedPath.sgColumn < frozenCount {
            self.selectRowAtIndexPath(indexPath, animated: animated)
        } else {
            self.collectionView.selectItem(at: convertedPath, animated: animated, scrollPosition: UICollectionView.ScrollPosition())
        }
    }

    open func deselectCellAtIndexPath(_ indexPath: IndexPath, animated: Bool) {
        guard let frozenCount = self.dataSource?.numberOfFrozenColumnsInDataGridView?(self) else { return }

        let convertedPath = self.reverseIndexPathConversion(indexPath)
        if convertedPath.sgColumn < frozenCount {
            self.deselectRowAtIndexPath(indexPath, animated: animated)
        } else {
            self.collectionView.deselectItem(at: convertedPath, animated: animated)
        }
    }

    open func deselectAllCells(animated: Bool) {
        for itemPath in self.collectionView.indexPathsForSelectedItems ?? [] {
            self.collectionView.deselectItem(at: itemPath, animated: animated)
        }
    }

    open func selectHeaderAtIndexPath(_ indexPath: IndexPath) {
        self.selectReusableViewOfKind(SwiftGridElementKindHeader, atIndexPath: indexPath)
    }

    open func deselectHeaderAtIndexPath(_ indexPath: IndexPath) {
        self.deselectReusableViewOfKind(SwiftGridElementKindHeader, atIndexPath: indexPath)
    }

    open func selectFooterAtIndexPath(_ indexPath: IndexPath) {
        self.selectReusableViewOfKind(SwiftGridElementKindFooter, atIndexPath: indexPath)
    }

    open func deselectFooterAtIndexPath(_ indexPath: IndexPath) {
        self.deselectReusableViewOfKind(SwiftGridElementKindFooter, atIndexPath: indexPath)
    }

    open func selectSectionHeaderAtIndexPath(_ indexPath: IndexPath) {
        if self.rowSelectionEnabled {
            self.toggleSelectedOnReusableViewRowOfKind(SwiftGridElementKindSectionHeader, atIndexPath: indexPath, selected: true)
        } else {
            self.selectReusableViewOfKind(SwiftGridElementKindSectionHeader, atIndexPath: indexPath)
        }
    }

    open func deselectSectionHeaderAtIndexPath(_ indexPath: IndexPath) {
        if self.rowSelectionEnabled {
            self.toggleSelectedOnReusableViewRowOfKind(SwiftGridElementKindSectionHeader, atIndexPath: indexPath, selected: false)
        } else {
            self.deselectReusableViewOfKind(SwiftGridElementKindSectionHeader, atIndexPath: indexPath)
        }
    }

    open func selectSectionFooterAtIndexPath(_ indexPath: IndexPath) {
        if self.rowSelectionEnabled {
            self.toggleSelectedOnReusableViewRowOfKind(SwiftGridElementKindSectionFooter, atIndexPath: indexPath, selected: true)
        } else {
            self.selectReusableViewOfKind(SwiftGridElementKindSectionFooter, atIndexPath: indexPath)
        }
    }

    open func deselectSectionFooterAtIndexPath(_ indexPath: IndexPath) {
        if self.rowSelectionEnabled {
            self.toggleSelectedOnReusableViewRowOfKind(SwiftGridElementKindSectionFooter, atIndexPath: indexPath, selected: false)
        } else {
            self.deselectReusableViewOfKind(SwiftGridElementKindSectionFooter, atIndexPath: indexPath)
        }
    }

    open func scrollToCellAtIndexPath(_ indexPath: IndexPath, atScrollPosition scrollPosition: UICollectionView.ScrollPosition, animated: Bool) {
        let convertedPath = self.reverseIndexPathConversion(indexPath)
        var absolutePostion = self.sgCollectionViewLayout.rectForItem(at: convertedPath, atScrollPosition: scrollPosition)

        // Adjust offset to not overflow content area based on viewsize
        if self.sgCollectionViewLayout.collectionViewContentSize.height - absolutePostion.origin.y < self.collectionView.frame.size.height {
            absolutePostion.origin.y = self.sgCollectionViewLayout.collectionViewContentSize.height - self.collectionView.frame.size.height

            if absolutePostion.origin.y < 0 {
                absolutePostion.origin.y = 0
            }
        }

        self.collectionView.setContentOffset(absolutePostion.origin, animated: animated)
    }

    open func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        self.collectionView.setContentOffset(contentOffset, animated: animated)
    }

    open func location(for gestureRecognizer: UIGestureRecognizer) -> CGPoint {
        return gestureRecognizer.location(in: self.collectionView)
    }

    // MARK: Private Pinch Recognizer

    @objc internal func handlePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.numberOfTouches != 2 {
            return
        }

        if recognizer.scale > 0.35, recognizer.scale < 5 {
            self.sgCollectionViewLayout.zoomScale = recognizer.scale
        }
    }

    @objc internal func handleTwoFingerTapGesture(_ recognizer: UITapGestureRecognizer) {
        if self.sgCollectionViewLayout.zoomScale != 1.0 {
            self.sgCollectionViewLayout.zoomScale = 1.0
        }
    }

    // MARK: Private conversion Methods

    fileprivate func convertCVIndexPathToSGIndexPath(_ indexPath: IndexPath) -> IndexPath {
        let row: Int = indexPath.row / self.sgColumnCount
        let column: Int = indexPath.row % self.sgColumnCount

        let convertedPath: IndexPath = IndexPath(forSGRow: row, atColumn: column, inSection: indexPath.section)

        return convertedPath
    }

    fileprivate func reverseIndexPathConversion(_ indexPath: IndexPath) -> IndexPath {
        let item: Int = indexPath.sgRow * self.sgColumnCount + indexPath.sgColumn
        let revertedPath: IndexPath = IndexPath(item: item, section: indexPath.sgSection)

        return revertedPath
    }

    fileprivate func reverseIndexPathConversionForIndexPaths(_ indexPaths: [IndexPath]) -> [IndexPath] {
        let convertedPaths = NSMutableArray()

        for indexPath in indexPaths {
            let convertedPath = self.reverseIndexPathConversion(indexPath)
            convertedPaths.add(convertedPath)
        }

        return convertedPaths.copy() as! [IndexPath]
    }

    fileprivate func numberOfRowsInSection(_ section: Int) -> Int {
        return self.dataSource!.dataGridView(self, numberOfRowsInSection: section)
    }

    // MARK: SwiftGridReusableViewDelegate Methods

    open func swiftGridReusableView(_ reusableView: SwiftGridReusableView, didSelectViewAtIndexPath indexPath: IndexPath) {
        switch reusableView.elementKind {
        case SwiftGridElementKindSectionHeader:
            self.selectReusableViewOfKind(reusableView.elementKind, atIndexPath: reusableView.indexPath as IndexPath)

            if self.rowSelectionEnabled {
                self.toggleSelectedOnReusableViewRowOfKind(reusableView.elementKind, atIndexPath: indexPath, selected: true)
            }

            self.delegate?.dataGridView?(self, didSelectSectionHeaderAtIndexPath: indexPath)
        case SwiftGridElementKindSectionFooter:
            self.selectReusableViewOfKind(reusableView.elementKind, atIndexPath: reusableView.indexPath as IndexPath)

            if self.rowSelectionEnabled {
                self.toggleSelectedOnReusableViewRowOfKind(reusableView.elementKind, atIndexPath: indexPath, selected: true)
            }

            self.delegate?.dataGridView?(self, didSelectSectionFooterAtIndexPath: indexPath)
        case SwiftGridElementKindHeader:
            self.selectReusableViewOfKind(reusableView.elementKind, atIndexPath: indexPath)

            self.delegate?.dataGridView?(self, didSelectHeaderAtIndexPath: indexPath)
        case SwiftGridElementKindGroupedHeader:
            self.selectReusableViewOfKind(reusableView.elementKind, atIndexPath: indexPath)

            self.delegate?.dataGridView?(self, didSelectGroupedHeader: self.groupedColumns[indexPath.sgColumn], at: indexPath.sgColumn)
        case SwiftGridElementKindFooter:
            self.selectReusableViewOfKind(reusableView.elementKind, atIndexPath: indexPath)

            self.delegate?.dataGridView?(self, didSelectFooterAtIndexPath: indexPath)
        default:
            break
        }
    }

    open func swiftGridReusableView(_ reusableView: SwiftGridReusableView, didDeselectViewAtIndexPath indexPath: IndexPath) {
        switch reusableView.elementKind {
        case SwiftGridElementKindSectionHeader:
            self.deselectReusableViewOfKind(reusableView.elementKind, atIndexPath: reusableView.indexPath as IndexPath)

            if self.rowSelectionEnabled {
                self.toggleSelectedOnReusableViewRowOfKind(reusableView.elementKind, atIndexPath: indexPath, selected: false)
            }

            self.delegate?.dataGridView?(self, didDeselectSectionHeaderAtIndexPath: indexPath)
        case SwiftGridElementKindSectionFooter:
            self.deselectReusableViewOfKind(reusableView.elementKind, atIndexPath: reusableView.indexPath as IndexPath)

            if self.rowSelectionEnabled {
                self.toggleSelectedOnReusableViewRowOfKind(reusableView.elementKind, atIndexPath: indexPath, selected: false)
            }

            self.delegate?.dataGridView?(self, didDeselectSectionFooterAtIndexPath: indexPath)
        case SwiftGridElementKindHeader:
            self.deselectReusableViewOfKind(reusableView.elementKind, atIndexPath: indexPath)

            self.delegate?.dataGridView?(self, didDeselectHeaderAtIndexPath: indexPath)
        case SwiftGridElementKindGroupedHeader:
            self.deselectReusableViewOfKind(reusableView.elementKind, atIndexPath: indexPath)

            self.delegate?.dataGridView?(self, didDeselectGroupedHeader: self.groupedColumns[indexPath.sgColumn], at: indexPath.sgColumn)
        case SwiftGridElementKindFooter:
            self.deselectReusableViewOfKind(reusableView.elementKind, atIndexPath: indexPath)

            self.delegate?.dataGridView?(self, didDeselectFooterAtIndexPath: indexPath)
        default:
            break
        }
    }

    open func swiftGridReusableView(_ reusableView: SwiftGridReusableView, didHighlightViewAtIndexPath indexPath: IndexPath) {
        switch reusableView.elementKind {
        case SwiftGridElementKindSectionHeader:

            if self.rowSelectionEnabled {
                self.toggleHighlightOnReusableViewRowOfKind(reusableView.elementKind, atIndexPath: indexPath, highlighted: true)
            }
        case SwiftGridElementKindSectionFooter:

            if self.rowSelectionEnabled {
                self.toggleHighlightOnReusableViewRowOfKind(reusableView.elementKind, atIndexPath: indexPath, highlighted: true)
            }
        case SwiftGridElementKindHeader:
            break
        case SwiftGridElementKindGroupedHeader:
            break
        case SwiftGridElementKindFooter:
            break
        default:
            break
        }
    }

    open func swiftGridReusableView(_ reusableView: SwiftGridReusableView, didUnhighlightViewAtIndexPath indexPath: IndexPath) {
        switch reusableView.elementKind {
        case SwiftGridElementKindSectionHeader:

            if self.rowSelectionEnabled {
                self.toggleHighlightOnReusableViewRowOfKind(reusableView.elementKind, atIndexPath: indexPath, highlighted: false)
            }
        case SwiftGridElementKindSectionFooter:

            if self.rowSelectionEnabled {
                self.toggleHighlightOnReusableViewRowOfKind(reusableView.elementKind, atIndexPath: indexPath, highlighted: false)
            }
        case SwiftGridElementKindHeader:
            break
        case SwiftGridElementKindGroupedHeader:
            break
        case SwiftGridElementKindFooter:
            break
        default:
            break
        }
    }

    fileprivate func toggleSelectedOnReusableViewRowOfKind(_ kind: String, atIndexPath indexPath: IndexPath, selected: Bool) {
        for columnIndex in 0...self.sgColumnCount - 1 {
            let sgPath = IndexPath(forSGRow: indexPath.sgRow, atColumn: columnIndex, inSection: indexPath.sgSection)
            let itemPath = self.reverseIndexPathConversion(sgPath)

            if selected {
                self.selectReusableViewOfKind(kind, atIndexPath: sgPath)
            } else {
                self.deselectReusableViewOfKind(kind, atIndexPath: sgPath)
            }

            guard let reusableView = self.collectionView.supplementaryView(forElementKind: kind, at: itemPath) as? SwiftGridReusableView
            else {
                continue
            }

            reusableView.selected = selected
        }
    }

    fileprivate func selectReusableViewOfKind(_ kind: String, atIndexPath indexPath: IndexPath) {
        switch kind {
        case SwiftGridElementKindSectionHeader:
            self.selectedSectionHeaders[indexPath] = true
        case SwiftGridElementKindSectionFooter:
            self.selectedSectionFooters[indexPath] = true
        case SwiftGridElementKindHeader:
            self.selectedHeaders[indexPath] = true
        case SwiftGridElementKindGroupedHeader:
            self.selectedGroupedHeaders[indexPath] = true
        case SwiftGridElementKindFooter:
            self.selectedFooters[indexPath] = true
        default:
            break
        }
    }

    fileprivate func deselectReusableViewOfKind(_ kind: String, atIndexPath indexPath: IndexPath) {
        switch kind {
        case SwiftGridElementKindSectionHeader:
            self.selectedSectionHeaders.removeObject(forKey: indexPath)
        case SwiftGridElementKindSectionFooter:
            self.selectedSectionFooters.removeObject(forKey: indexPath)
        case SwiftGridElementKindHeader:
            self.selectedHeaders.removeObject(forKey: indexPath)
        case SwiftGridElementKindGroupedHeader:
            self.selectedGroupedHeaders.removeObject(forKey: indexPath)
        case SwiftGridElementKindFooter:
            self.selectedFooters.removeObject(forKey: indexPath)
        default:
            break
        }
    }

    fileprivate func toggleHighlightOnReusableViewRowOfKind(_ kind: String, atIndexPath indexPath: IndexPath, highlighted: Bool) {
        for columnIndex in 0...self.sgColumnCount - 1 {
            let sgPath = IndexPath(forSGRow: indexPath.sgRow, atColumn: columnIndex, inSection: indexPath.sgSection)
            let itemPath = self.reverseIndexPathConversion(sgPath)
            guard let reusableView = self.collectionView.supplementaryView(forElementKind: kind, at: itemPath) as? SwiftGridReusableView
            else {
                continue
            }

            reusableView.highlighted = highlighted
        }
    }

    // MARK: SwiftGridLayoutDelegate Methods

    internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        let convertedPath: IndexPath = self.convertCVIndexPathToSGIndexPath(indexPath)
        let colWidth: CGFloat = self.delegate!.dataGridView(self, widthOfColumnAtIndex: convertedPath.sgColumn)
        let rowHeight: CGFloat = self.delegate!.dataGridView(self, heightOfRowAtIndexPath: convertedPath)

        return CGSize(width: colWidth, height: rowHeight)
    }

    internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, heightFor row: Int, at indexPath: IndexPath) -> CGFloat {
        let convertedPath: IndexPath = IndexPath(forSGRow: row, atColumn: 0, inSection: indexPath.section)

        return self.delegate!.dataGridView(self, heightOfRowAtIndexPath: convertedPath)
    }

    internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, heightForSupplementaryViewOfKind kind: String, atIndexPath indexPath: IndexPath) -> CGFloat {
        var rowHeight: CGFloat = 0

        switch kind {
        case SwiftGridElementKindHeader:
            if let delegateHeight = self.delegate?.heightForGridHeaderInDataGridView?(self) {
                if delegateHeight > 0 {
                    rowHeight = delegateHeight
                }
            }
        case SwiftGridElementKindFooter:
            if let delegateHeight = self.delegate?.heightForGridFooterInDataGridView?(self) {
                if delegateHeight > 0 {
                    rowHeight = delegateHeight
                }
            }
        case SwiftGridElementKindSectionHeader:
            if let delegateHeight = self.delegate?.dataGridView?(self, heightOfHeaderInSection: indexPath.section) {
                if delegateHeight > 0 {
                    rowHeight = delegateHeight
                }
            }
        case SwiftGridElementKindSectionFooter:
            if let delegateHeight = self.delegate?.dataGridView?(self, heightOfFooterInSection: indexPath.section) {
                if delegateHeight > 0 {
                    rowHeight = delegateHeight
                }
            }
        case SwiftGridElementKindGroupedHeader:
            if let delegateHeight = self.delegate?.heightForGridHeaderInDataGridView?(self) {
                if delegateHeight > 0 {
                    rowHeight = delegateHeight
                }
            }
        default:
            rowHeight = 0
        }

        return rowHeight
    }

    internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForSupplementaryViewOfKind kind: String, atIndexPath indexPath: IndexPath) -> CGSize {
        var colWidth: CGFloat = 0.0
        let rowHeight: CGFloat = self.collectionView(collectionView, layout: collectionViewLayout, heightForSupplementaryViewOfKind: kind, atIndexPath: indexPath)

        if indexPath.count != 0, kind != SwiftGridElementKindGroupedHeader {
            colWidth = self.delegate!.dataGridView(self, widthOfColumnAtIndex: indexPath.row)
        } else if kind == SwiftGridElementKindGroupedHeader {
            let grouping = self.groupedColumns[indexPath.item]

            for column in grouping[0]...grouping[1] {
                colWidth += self.delegate!.dataGridView(self, widthOfColumnAtIndex: column)
            }
        }

        return CGSize(width: colWidth, height: rowHeight)
    }

    internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, numberOfRowsInSection sectionIndex: Int) -> Int {
        return self.numberOfRowsInSection(sectionIndex)
    }

    internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, numberOfFrozenRowsInSection sectionIndex: Int) -> Int {
        if let frozenRows = self.dataSource?.dataGridView?(self, numberOfFrozenRowsInSection: sectionIndex) {
            return frozenRows
        }

        return 0
    }

    internal func collectionView(_ collectionView: UICollectionView, numberOfColumnsForLayout collectionViewLayout: UICollectionViewLayout) -> Int {
        return self.sgColumnCount
    }

    internal func collectionView(_ collectionView: UICollectionView, groupedColumnsForLayout collectionViewLayout: UICollectionViewLayout) -> [[Int]] {
        return self.groupedColumns
    }

    internal func collectionView(_ collectionView: UICollectionView, numberOfFrozenColumnsForLayout collectionViewLayout: UICollectionViewLayout) -> Int {
        if let frozenCount = self.dataSource?.numberOfFrozenColumnsInDataGridView?(self) {
            return frozenCount
        } else {
            return 0
        }
    }

    internal func collectionView(_ collectionView: UICollectionView, totalColumnWidthForLayout collectionViewLayout: UICollectionViewLayout) -> CGFloat {
        return self.sgColumnWidth
    }

    internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, widthOfColumnAtIndex columnIndex: Int) -> CGFloat {
        return self.delegate!.dataGridView(self, widthOfColumnAtIndex: columnIndex)
    }

    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.delegate!.scrollViewDidEndDeceleratingDataGridView?(self)
    }

    open func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        self.delegate?.scrollViewWillEndDraggingDataGridView?(self)
    }

    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.delegate?.scrollViewDidScrollDataGridView?(self)
    }

    // MARK: UICollectionView DataSource

    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.sgSectionCount
    }

    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberOfCells: Int = self.sgColumnCount * self.numberOfRowsInSection(section)

        return numberOfCells
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = self.dataSource!.dataGridView(self, cellAtIndexPath: self.convertCVIndexPathToSGIndexPath(indexPath))

        return cell
    }

    // TODO: Make this more fail friendly?
    open func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        var reusableView: SwiftGridReusableView
        let convertedPath = self.convertCVIndexPathToSGIndexPath(indexPath)

        switch kind {
        case SwiftGridElementKindSectionHeader:
            reusableView = self.dataSource!.dataGridView!(self, sectionHeaderCellAtIndexPath: convertedPath)
            reusableView.selected = self.selectedSectionHeaders[convertedPath] != nil ? true : false
        case SwiftGridElementKindSectionFooter:
            reusableView = self.dataSource!.dataGridView!(self, sectionFooterCellAtIndexPath: convertedPath)
            reusableView.selected = self.selectedSectionFooters[convertedPath] != nil ? true : false
        case SwiftGridElementKindHeader:
            reusableView = self.dataSource!.dataGridView!(self, gridHeaderViewForColumn: convertedPath.sgColumn)
            reusableView.selected = self.selectedHeaders[convertedPath] != nil ? true : false
        case SwiftGridElementKindGroupedHeader:
            reusableView = self.dataSource!.dataGridView!(self, groupedHeaderViewFor: self.groupedColumns[indexPath.item], at: indexPath.item)
            reusableView.selected = self.selectedGroupedHeaders[convertedPath] != nil ? true : false
        case SwiftGridElementKindFooter:
            reusableView = self.dataSource!.dataGridView!(self, gridFooterViewForColumn: convertedPath.sgColumn)
            reusableView.selected = self.selectedFooters[convertedPath] != nil ? true : false
        default:
            reusableView = SwiftGridReusableView(frame: CGRect.zero)
        }

        reusableView.delegate = self
        reusableView.indexPath = convertedPath
        reusableView.elementKind = kind

        return reusableView
    }

    // MARK: UICollectionView Delegate

    open func selectRowAtIndexPath(_ indexPath: IndexPath, animated: Bool) {
        for columnIndex in 0...self.sgColumnCount - 1 {
            let sgPath = IndexPath(forSGRow: indexPath.sgRow, atColumn: columnIndex, inSection: indexPath.sgSection)
            let itemPath = self.reverseIndexPathConversion(sgPath)
            self.collectionView.selectItem(at: itemPath, animated: animated, scrollPosition: UICollectionView.ScrollPosition())
        }
    }

    fileprivate func selectRowByColumnAtIndexPath(_ indexPath: IndexPath, animated: Bool) {
        let headerPath = IndexPath(forSGRow: 0, atColumn: indexPath.sgColumn, inSection: indexPath.sgSection)
        self.selectHeaderAtIndexPath(headerPath)
        if let headerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindHeader, at: self.reverseIndexPathConversion(headerPath)) as? SwiftGridReusableView {
            headerView.selected = true
        }

        let footerPath = IndexPath(forSGRow: 0, atColumn: indexPath.sgColumn, inSection: indexPath.sgSection)
        self.selectFooterAtIndexPath(footerPath)
        if let footerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindFooter, at: self.reverseIndexPathConversion(footerPath)) as? SwiftGridReusableView {
            footerView.selected = true
        }

        for section in 0..<self.sgSectionCount {
            let footerPath = IndexPath(forSGRow: 0, atColumn: indexPath.sgColumn, inSection: section)
            self.selectSectionFooterAtIndexPath(footerPath)
            if let footerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindSectionFooter, at: self.reverseIndexPathConversion(footerPath)) as? SwiftGridReusableView {
                footerView.selected = true
            }

            let rows = self.numberOfRowsInSection(section)
            if rows > 0 {
                for rowIndex in 0...rows - 1 {
                    let sgPath = IndexPath(forSGRow: rowIndex, atColumn: indexPath.sgColumn, inSection: section)
                    let itemPath = self.reverseIndexPathConversion(sgPath)
                    self.collectionView.selectItem(at: itemPath, animated: animated, scrollPosition: UICollectionView.ScrollPosition())
                }
            }
        }
    }

    open func deselectRowAtIndexPath(_ indexPath: IndexPath, animated: Bool) {
        for columnIndex in 0...self.sgColumnCount - 1 {
            let sgPath = IndexPath(forSGRow: indexPath.sgRow, atColumn: columnIndex, inSection: indexPath.sgSection)
            let itemPath = self.reverseIndexPathConversion(sgPath)
            self.collectionView.deselectItem(at: itemPath, animated: animated)
        }
    }

    fileprivate func deselectRowByColumnAtIndexPath(_ indexPath: IndexPath, animated: Bool) {
        let headerPath = IndexPath(forSGRow: 0, atColumn: indexPath.sgColumn, inSection: indexPath.sgSection)
        self.deselectHeaderAtIndexPath(headerPath)
        if let headerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindHeader, at: self.reverseIndexPathConversion(headerPath)) as? SwiftGridReusableView {
            headerView.selected = false
        }

        let footerPath = IndexPath(forSGRow: 0, atColumn: indexPath.sgColumn, inSection: indexPath.sgSection)
        self.deselectFooterAtIndexPath(footerPath)
        if let footerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindFooter, at: self.reverseIndexPathConversion(footerPath)) as? SwiftGridReusableView {
            footerView.selected = false
        }

        for section in 0..<self.sgSectionCount {
            let footerPath = IndexPath(forSGRow: 0, atColumn: indexPath.sgColumn, inSection: section)
            self.selectSectionFooterAtIndexPath(footerPath)
            if let footerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindSectionFooter, at: self.reverseIndexPathConversion(footerPath)) as? SwiftGridReusableView {
                footerView.selected = false
            }

            let rows = self.numberOfRowsInSection(section)
            for rowIndex in 0...rows - 1 {
                let sgPath = IndexPath(forSGRow: rowIndex, atColumn: indexPath.sgColumn, inSection: section)
                let itemPath = self.reverseIndexPathConversion(sgPath)
                self.collectionView.deselectItem(at: itemPath, animated: animated)
            }
        }
    }

    fileprivate func deselectAllItemsIgnoring(_ indexPath: IndexPath, animated: Bool) {
        self.selectedHeaders.allKeys.forEach {
            let headerPath = $0 as! IndexPath
            self.deselectHeaderAtIndexPath(headerPath)
            let revertedPath = self.reverseIndexPathConversion(headerPath)
            if let headerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindHeader, at: revertedPath) as? SwiftGridReusableView {
                headerView.selected = false
            }
        }
        self.selectedFooters.allKeys.forEach {
            let footerPath = $0 as! IndexPath
            self.deselectFooterAtIndexPath(footerPath)
            let revertedPath = self.reverseIndexPathConversion(footerPath)
            if let footerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindFooter, at: revertedPath) as? SwiftGridReusableView {
                footerView.selected = false
            }
        }

        self.selectedSectionFooters.allKeys.forEach {
            let footerPath = $0 as! IndexPath
            self.deselectSectionFooterAtIndexPath(footerPath)
            let revertedPath = self.reverseIndexPathConversion(footerPath)
            if let footerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindSectionFooter, at: revertedPath) as? SwiftGridReusableView {
                footerView.selected = false
            }
        }

        for itemPath in self.collectionView.indexPathsForSelectedItems ?? [] {
            if itemPath.item == indexPath.item {
                continue
            }
            self.collectionView.deselectItem(at: itemPath, animated: animated)
        }
    }

    fileprivate func toggleHighlightOnRowAtIndexPath(_ indexPath: IndexPath, highlighted: Bool) {
        for columnIndex in 0...self.sgColumnCount - 1 {
            let sgPath = IndexPath(forSGRow: indexPath.sgRow, atColumn: columnIndex, inSection: indexPath.sgSection)
            let itemPath = self.reverseIndexPathConversion(sgPath)
            self.collectionView.cellForItem(at: itemPath)?.isHighlighted = highlighted
        }
    }

    open func selectSingleColumnSelection(_ indexPath: IndexPath) {
        self.selectRowByColumnAtIndexPath(indexPath, animated: false)
    }

    open func deselectSingleColumnSelection(_ indexPath: IndexPath) {
        self.deselectRowByColumnAtIndexPath(indexPath, animated: false)
    }

    open func deselectColumnsSelection(ignoredSelectedColumn: Int? = nil) {
        self.selectedHeaders.allKeys.forEach {
            let headerPath = $0 as! IndexPath

            if let ignored = ignoredSelectedColumn, ignored == headerPath.sgColumn {
                return
            }

            self.deselectHeaderAtIndexPath(headerPath)
            let revertedPath = self.reverseIndexPathConversion(headerPath)
            if let headerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindHeader, at: revertedPath) as? SwiftGridReusableView {
                headerView.selected = false
            }

            for section in 0..<self.sgSectionCount {
                let rows = self.numberOfRowsInSection(section)
                if rows > 0 {
                    for rowIndex in 0...rows - 1 {
                        let sgPath = IndexPath(forSGRow: rowIndex, atColumn: headerPath.sgColumn, inSection: section)
                        let itemPath = self.reverseIndexPathConversion(sgPath)
                        self.collectionView.deselectItem(at: itemPath, animated: false)
                    }
                }
            }
        }
        self.selectedFooters.allKeys.forEach {
            let footerPath = $0 as! IndexPath

            if let ignored = ignoredSelectedColumn, ignored == footerPath.sgColumn {
                return
            }

            self.deselectFooterAtIndexPath(footerPath)
            let revertedPath = self.reverseIndexPathConversion(footerPath)
            if let footerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindFooter, at: revertedPath) as? SwiftGridReusableView {
                footerView.selected = false
            }
        }
        self.selectedSectionFooters.allKeys.forEach {
            let footerPath = $0 as! IndexPath

            if let ignored = ignoredSelectedColumn, ignored == footerPath.sgColumn {
                return
            }

            self.deselectSectionFooterAtIndexPath(footerPath)
            let revertedPath = self.reverseIndexPathConversion(footerPath)
            if let footerView = collectionView?.supplementaryView(forElementKind: SwiftGridElementKindSectionFooter, at: revertedPath) as? SwiftGridReusableView {
                footerView.selected = false
            }
        }
    }

    open func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        guard let frozenCount = self.dataSource?.numberOfFrozenColumnsInDataGridView?(self) else { return }

        let convertedPath = self.convertCVIndexPathToSGIndexPath(indexPath)
        if convertedPath.sgColumn < frozenCount {
            self.toggleHighlightOnRowAtIndexPath(convertedPath, highlighted: true)
        }
    }

    open func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        guard let frozenCount = self.dataSource?.numberOfFrozenColumnsInDataGridView?(self) else { return }

        let convertedPath = self.convertCVIndexPathToSGIndexPath(indexPath)
        if convertedPath.sgColumn < frozenCount {
            self.toggleHighlightOnRowAtIndexPath(convertedPath, highlighted: false)
        }
    }

    open func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return userTouchCellEnabled == true
    }

    open func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return userTouchCellEnabled == true
    }

    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let convertedPath = self.convertCVIndexPathToSGIndexPath(indexPath)

        if self.allowsMultipleSelection {
            self.deselectColumnsSelection()
        } else {
            self.deselectAllItemsIgnoring(indexPath, animated: false)
        }

        guard let frozenCount = self.dataSource?.numberOfFrozenColumnsInDataGridView?(self) else { return }

        if convertedPath.sgColumn < frozenCount {
            self.selectRowAtIndexPath(convertedPath, animated: false)

            if crossSelectionEnabled, convertedPath.sgColumn > 0 {
                if self.allowsMultipleSelection {
                } else {
                    self.selectRowByColumnAtIndexPath(convertedPath, animated: false)
                }
            }
        }

        self.delegate?.dataGridView?(self, didSelectCellAtIndexPath: convertedPath)
    }

    open func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let convertedPath = self.convertCVIndexPathToSGIndexPath(indexPath)
        self.deselectRowByColumnAtIndexPath(convertedPath, animated: false)

        if let frozenCount = self.dataSource?.numberOfFrozenColumnsInDataGridView?(self), convertedPath.sgColumn < frozenCount {
            self.deselectRowAtIndexPath(convertedPath, animated: false)
        }

        if self.selectedHeaders.count == 0 {
            self.deselectRowAtIndexPath(convertedPath, animated: false)
        }

        self.delegate?.dataGridView?(self, didDeselectCellAtIndexPath: convertedPath)
    }
}
