//
//  LogoMark.swift
//  FarmerChat
//
//  SwiftUI vector version of Android res/drawable/logo_mark.xml
//

import SwiftUI

/// FarmerChat "mark" rendered from the Android vector path data (viewport 130×130).
struct LogoMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        func addBlob(
            moveTo: CGPoint,
            c1: CGPoint, c2: CGPoint, to1: CGPoint,
            c3: CGPoint, c4: CGPoint, to2: CGPoint
        ) {
            p.move(to: moveTo)
            p.addCurve(to: to1, control1: c1, control2: c2)
            p.addCurve(to: to2, control1: c3, control2: c4)
            p.closeSubpath()
        }

        // Paths copied from logo_mark.xml (fillColor #000000).
        addBlob(
            moveTo: .init(x: 32.56, y: 0),
            c1: .init(x: 50.54, y: 0), c2: .init(x: 65.12, y: 14.59), to1: .init(x: 65.12, y: 32.59),
            c3: .init(x: 47.14, y: 32.59), c4: .init(x: 32.56, y: 18), to2: .init(x: 32.56, y: 0)
        )
        addBlob(
            moveTo: .init(x: 97.56, y: 0),
            c1: .init(x: 79.58, y: 0), c2: .init(x: 65, y: 14.59), to1: .init(x: 65, y: 32.59),
            c3: .init(x: 82.98, y: 32.59), c4: .init(x: 97.56, y: 18), to2: .init(x: 97.56, y: 0)
        )
        addBlob(
            moveTo: .init(x: 32.68, y: 65.06),
            c1: .init(x: 14.7, y: 65.06), c2: .init(x: 0.12, y: 50.47), to1: .init(x: 0.12, y: 32.47),
            c3: .init(x: 18.1, y: 32.47), c4: .init(x: 32.68, y: 47.06), to2: .init(x: 32.68, y: 65.06)
        )
        addBlob(
            moveTo: .init(x: 65.12, y: 32.47),
            c1: .init(x: 47.14, y: 32.47), c2: .init(x: 32.56, y: 47.06), to1: .init(x: 32.56, y: 65.06),
            c3: .init(x: 50.54, y: 65.06), c4: .init(x: 65.12, y: 50.47), to2: .init(x: 65.12, y: 32.47)
        )
        addBlob(
            moveTo: .init(x: 65, y: 32.47),
            c1: .init(x: 82.98, y: 32.47), c2: .init(x: 97.56, y: 47.06), to1: .init(x: 97.56, y: 65.06),
            c3: .init(x: 79.58, y: 65.06), c4: .init(x: 65, y: 50.47), to2: .init(x: 65, y: 32.47)
        )
        addBlob(
            moveTo: .init(x: 97.44, y: 65.06),
            c1: .init(x: 115.42, y: 65.06), c2: .init(x: 130, y: 50.47), to1: .init(x: 130, y: 32.47),
            c3: .init(x: 112.02, y: 32.47), c4: .init(x: 97.44, y: 47.06), to2: .init(x: 97.44, y: 65.06)
        )
        addBlob(
            moveTo: .init(x: 32.56, y: 64.94),
            c1: .init(x: 14.58, y: 64.94), c2: .init(x: 0, y: 79.53), to1: .init(x: 0, y: 97.53),
            c3: .init(x: 17.98, y: 97.53), c4: .init(x: 32.56, y: 82.94), to2: .init(x: 32.56, y: 64.94)
        )
        addBlob(
            moveTo: .init(x: 32.56, y: 64.94),
            c1: .init(x: 50.54, y: 64.94), c2: .init(x: 65.12, y: 79.53), to1: .init(x: 65.12, y: 97.53),
            c3: .init(x: 47.14, y: 97.53), c4: .init(x: 32.56, y: 82.94), to2: .init(x: 32.56, y: 64.94)
        )
        addBlob(
            moveTo: .init(x: 97.56, y: 64.94),
            c1: .init(x: 79.58, y: 64.94), c2: .init(x: 65, y: 79.53), to1: .init(x: 65, y: 97.53),
            c3: .init(x: 82.98, y: 97.53), c4: .init(x: 97.56, y: 82.94), to2: .init(x: 97.56, y: 64.94)
        )
        addBlob(
            moveTo: .init(x: 97.44, y: 64.94),
            c1: .init(x: 115.42, y: 64.94), c2: .init(x: 130, y: 79.53), to1: .init(x: 130, y: 97.53),
            c3: .init(x: 112.02, y: 97.53), c4: .init(x: 97.44, y: 82.94), to2: .init(x: 97.44, y: 64.94)
        )
        addBlob(
            moveTo: .init(x: 65.12, y: 97.41),
            c1: .init(x: 47.14, y: 97.41), c2: .init(x: 32.56, y: 112), to1: .init(x: 32.56, y: 130),
            c3: .init(x: 50.54, y: 130), c4: .init(x: 65.12, y: 115.41), to2: .init(x: 65.12, y: 97.41)
        )
        addBlob(
            moveTo: .init(x: 65, y: 97.41),
            c1: .init(x: 82.98, y: 97.41), c2: .init(x: 97.56, y: 112), to1: .init(x: 97.56, y: 130),
            c3: .init(x: 79.58, y: 130), c4: .init(x: 65, y: 115.41), to2: .init(x: 65, y: 97.41)
        )

        // Scale viewport(130×130) into the supplied rect while preserving aspect ratio.
        let vw: CGFloat = 130
        let vh: CGFloat = 130
        let scale = min(rect.width / vw, rect.height / vh)
        let x = rect.midX - (vw * scale) / 2
        let y = rect.midY - (vh * scale) / 2
        let t = CGAffineTransform(translationX: x, y: y).scaledBy(x: scale, y: scale)
        return p.applying(t)
    }
}

