//
//  LayoutConstants.swift
//  Momentum
//
//  Created by Mo Moosa on 03/03/2026.
//

import Foundation

/// Layout constants used throughout the app
enum LayoutConstants {
    
    enum Heights {
        /// Standard suggestion panel height
        static let suggestionPanel: CGFloat = 400
        
        /// Filter bar height
        static let filterBar: CGFloat = 60
        
        /// Icon placeholder height
        static let iconPlaceholder: CGFloat = 20
        
        /// Standard row height
        static let rowHeight: CGFloat = 40
        
        /// Small spacer height
        static let smallSpacer: CGFloat = 10
    }
    
    enum ProgressCircle {
        /// Large progress circle diameter (for NowPlayingView)
        static let largeDiameter: CGFloat = 280
        
        /// Standard progress circle diameter
        static let standardDiameter: CGFloat = 80
        
        /// Large progress circle line width
        static let largeLineWidth: CGFloat = 20
        
        /// Standard progress circle line width
        static let standardLineWidth: CGFloat = 12
    }
    
    enum Padding {
        /// Standard edge padding
        static let standard: CGFloat = 16
        
        /// Small padding
        static let small: CGFloat = 8
        
        /// Large padding
        static let large: CGFloat = 24
    }
    
    enum CornerRadius {
        /// Standard corner radius
        static let standard: CGFloat = 12
        
        /// Small corner radius
        static let small: CGFloat = 8
        
        /// Large corner radius
        static let large: CGFloat = 16
    }
}
