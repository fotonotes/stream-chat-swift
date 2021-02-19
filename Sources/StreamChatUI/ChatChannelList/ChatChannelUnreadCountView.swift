//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

/// A view that shows a number of unread messages in channel.
internal typealias ChatChannelUnreadCountView = _ChatChannelUnreadCountView<NoExtraData>

/// A view that shows a number of unread messages in channel.
internal class _ChatChannelUnreadCountView<ExtraData: ExtraDataTypes>: _View, UIConfigProvider, SwiftUIRepresentable {
    /// The `UILabel` instance that holds number of unread messages.
    internal private(set) lazy var unreadCountLabel = UILabel()
        .withoutAutoresizingMaskConstraints
        .withAdjustingFontForContentSizeCategory
        .withBidirectionalLanguagesSupport

    /// The data this view component shows.
    internal var content: ChannelUnreadCount = .noUnread {
        didSet { updateContentIfNeeded() }
    }

    override internal func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    override public func defaultAppearance() {
        layer.masksToBounds = true
        backgroundColor = uiConfig.colorPalette.alert

        unreadCountLabel.textColor = uiConfig.colorPalette.staticColorText
        unreadCountLabel.font = uiConfig.fonts.footnoteBold
        unreadCountLabel.textAlignment = .center
    }

    override internal func setUpLayout() {
        // 2 and 3 are magic numbers that look visually good
        layoutMargins = .init(top: 2, left: 3, bottom: 2, right: 3)

        addSubview(unreadCountLabel)
        unreadCountLabel.pin(to: layoutMarginsGuide)

        // The width shouldn't be smaller than height because we want to show it as a circle for small numbers
        widthAnchor.pin(greaterThanOrEqualTo: heightAnchor, multiplier: 1).isActive = true
    }
    
    override open func updateContent() {
        isHidden = content.mentionedMessages == 0 && content.messages == 0
        unreadCountLabel.text = String(content.messages)
    }
}
