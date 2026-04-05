import AppKit
import CoreGraphics

class ScrollCaptureStitcher {

    /// Raw pixel buffer with top-left origin (row 0 = top of image)
    struct PixelBuffer {
        let pixels: [UInt8]
        let width: Int
        let height: Int
        let bytesPerRow: Int

        func pixel(row: Int, col: Int) -> (UInt8, UInt8, UInt8) {
            let idx = row * bytesPerRow + col * 4
            return (pixels[idx], pixels[idx + 1], pixels[idx + 2])
        }
    }

    static func stitch(frames: [CGImage]) -> NSImage? {
        guard !frames.isEmpty else { return nil }
        NSLog("[Stitcher] stitch called with \(frames.count) frames")

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        if frames.count == 1 {
            let ps = NSSize(width: CGFloat(frames[0].width) / scale, height: CGFloat(frames[0].height) / scale)
            return NSImage(cgImage: frames[0], size: ps)
        }

        // Convert all frames to top-down pixel buffers
        let buffers = frames.compactMap { toPixelBuffer($0) }
        guard buffers.count == frames.count else {
            NSLog("[Stitcher] normalization failed, falling back to concatenation")
            return simpleConcatenate(frames, scale: scale)
        }

        // Detect sticky header
        let headerHeight = detectStickyHeader(a: buffers[0], b: buffers[1])
        NSLog("[Stitcher] sticky header: \(headerHeight)px")

        // Find overlaps
        var overlaps: [Int] = []
        for i in 0..<(buffers.count - 1) {
            let ov = findOverlap(a: buffers[i], b: buffers[i + 1], headerHeight: headerHeight)
            NSLog("[Stitcher] overlap[\(i)->\(i+1)] = \(ov)")
            overlaps.append(ov)
        }

        // Fix outlier overlaps: if most overlaps are consistent (auto-scroll),
        // replace outliers with the median value
        overlaps = fixOutlierOverlaps(overlaps)

        // Render
        let result = renderStitched(frames: frames, overlaps: overlaps, scale: scale)
        NSLog("[Stitcher] render result: \(result != nil ? "ok" : "nil")")
        return result ?? simpleConcatenate(frames, scale: scale)
    }

    // MARK: - Outlier Correction

    /// If overlaps are mostly consistent (auto-scroll), replace outliers with the median.
    private static func fixOutlierOverlaps(_ overlaps: [Int]) -> [Int] {
        guard overlaps.count >= 4 else { return overlaps }

        // Only fix if there's a clear "dominant" overlap value
        let sorted = overlaps.sorted()
        let median = sorted[sorted.count / 2]

        guard median > 0 else { return overlaps }

        // Check if most values are close to median (within 15%)
        let tolerance = max(median * 15 / 100, 20)
        let closeCount = overlaps.filter { abs($0 - median) <= tolerance }.count
        guard closeCount >= overlaps.count * 2 / 3 else { return overlaps }

        // Replace outliers
        var fixed = overlaps
        for i in 0..<fixed.count {
            if abs(fixed[i] - median) > tolerance {
                NSLog("[Stitcher] fixing outlier overlap[\(i)]: \(fixed[i]) -> \(median)")
                fixed[i] = median
            }
        }
        return fixed
    }

    // MARK: - Pixel Buffer (top-down, safe array access)

    private static func toPixelBuffer(_ img: CGImage) -> PixelBuffer? {
        let w = img.width, h = img.height
        let bpr = w * 4
        let cs = CGColorSpaceCreateDeviceRGB()
        // Use kCGImageAlphaPremultipliedFirst + kCGBitmapByteOrder32Big for consistent ARGB
        // Actually use RGBA (premultipliedLast) which is simpler
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bpr, space: cs,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        // CGBitmapContext memory is already top-down (row 0 = top of image)
        // Just draw without flipping
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

        guard let data = ctx.data else { return nil }
        let bytes = Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: h * bpr))
        return PixelBuffer(pixels: bytes, width: w, height: h, bytesPerRow: bpr)
    }

    // MARK: - Sticky Header Detection

    private static func detectStickyHeader(a: PixelBuffer, b: PixelBuffer) -> Int {
        guard a.width == b.width else { return 0 }
        let w = a.width
        let maxCheck = min(a.height, b.height) / 4

        let colStart = w * 10 / 100
        let colEnd = w * 90 / 100
        let colStep = max(1, (colEnd - colStart) / 50)

        var headerHeight = 0
        for row in 0..<maxCheck {
            var matches = 0, total = 0
            for col in stride(from: colStart, to: colEnd, by: colStep) {
                let (r1, g1, b1) = a.pixel(row: row, col: col)
                let (r2, g2, b2) = b.pixel(row: row, col: col)
                total += 1
                if abs(Int(r1) - Int(r2)) <= 10 && abs(Int(g1) - Int(g2)) <= 10 && abs(Int(b1) - Int(b2)) <= 10 {
                    matches += 1
                }
            }
            if total > 0 && matches * 100 / total >= 95 {
                headerHeight = row + 1
            } else {
                break
            }
        }
        return headerHeight < 20 ? 0 : headerHeight
    }

    // MARK: - Overlap Detection

    /// Sample columns for pixel comparison (middle 70%, avoiding scrollbar edges)
    private static func buildSampleCols(width: Int) -> [Int] {
        var cols: [Int] = []
        let colStart = width * 15 / 100
        let colEnd = width * 85 / 100
        let colStep = max(1, (colEnd - colStart) / 50)
        for x in stride(from: colStart, to: colEnd, by: colStep) {
            cols.append(x)
        }
        return cols
    }

    /// Check if a single row in A matches the corresponding row in B (>= 90% pixels within tolerance)
    private static func rowMatches(a: PixelBuffer, rowA: Int, b: PixelBuffer, rowB: Int, sampleCols: [Int]) -> Bool {
        var matches = 0
        for col in sampleCols {
            let (r1, g1, b1) = a.pixel(row: rowA, col: col)
            let (r2, g2, b2) = b.pixel(row: rowB, col: col)
            if abs(Int(r1) - Int(r2)) <= 12 && abs(Int(g1) - Int(g2)) <= 12 && abs(Int(b1) - Int(b2)) <= 12 {
                matches += 1
            }
        }
        return matches * 100 / max(sampleCols.count, 1) >= 90
    }

    /// Check if a row is "trivial" (nearly uniform color — e.g., solid white/gray background)
    private static func rowIsTrivial(buf: PixelBuffer, row: Int, sampleCols: [Int]) -> Bool {
        guard sampleCols.count > 2 else { return false }
        let (r0, g0, b0) = buf.pixel(row: row, col: sampleCols[0])
        var sameCount = 0
        for col in sampleCols {
            let (r, g, b) = buf.pixel(row: row, col: col)
            if abs(Int(r) - Int(r0)) <= 8 && abs(Int(g) - Int(g0)) <= 8 && abs(Int(b) - Int(b0)) <= 8 {
                sameCount += 1
            }
        }
        return sameCount * 100 / sampleCols.count >= 95
    }

    private static func findOverlap(a: PixelBuffer, b: PixelBuffer, headerHeight: Int) -> Int {
        let h = a.height
        let w = a.width
        let sampleCols = buildSampleCols(width: w)

        let contentH = h - headerHeight
        let maxOverlap = contentH * 90 / 100
        let minOverlap = max(contentH / 20, 10)

        // Strategy: pick an "anchor row" near the bottom of A that has non-trivial content,
        // then search for it in B's content area. Once found, verify the full overlap.

        // Find a good anchor row (non-trivial, near bottom of A)
        var anchorRowA = -1
        for candidate in stride(from: h - 5, through: h - contentH / 2, by: -3) {
            if candidate >= 0 && !rowIsTrivial(buf: a, row: candidate, sampleCols: sampleCols) {
                anchorRowA = candidate
                break
            }
        }

        // If no non-trivial row near bottom, try from further up
        if anchorRowA < 0 {
            for candidate in stride(from: h - contentH / 2, through: headerHeight, by: -3) {
                if !rowIsTrivial(buf: a, row: candidate, sampleCols: sampleCols) {
                    anchorRowA = candidate
                    break
                }
            }
        }

        // Fallback: just use a row near the middle-bottom
        if anchorRowA < 0 {
            anchorRowA = h - contentH / 4
        }

        // Search for anchorRowA's content in B (below header)
        let bContentStart = headerHeight
        let bContentEnd = b.height

        for rowB in bContentStart..<bContentEnd {
            if rowMatches(a: a, rowA: anchorRowA, b: b, rowB: rowB, sampleCols: sampleCols) {
                // Found a candidate match. Calculate the implied overlap.
                // anchorRowA is at position (anchorRowA) from top of A
                // The bottom of A starts at row (h - overlap) when mapped to B's content at row bContentStart
                // So: anchorRowA - (h - overlap) = rowB - bContentStart
                // => overlap = h - anchorRowA + rowB - bContentStart
                let contentOverlap = h - anchorRowA + (rowB - bContentStart)
                let totalOverlap = headerHeight + contentOverlap

                guard contentOverlap >= minOverlap && contentOverlap <= maxOverlap else { continue }

                // Verify: check multiple rows across the overlap zone
                let verified = verifyOverlap(a: a, b: b, contentOverlap: contentOverlap,
                                              headerHeight: headerHeight, sampleCols: sampleCols)
                if verified {
                    return totalOverlap
                }
            }
        }

        // Fallback: header-only removal
        return headerHeight > 0 ? headerHeight : 0
    }

    /// Verify a candidate overlap by checking many rows across the zone.
    /// Requires >= 70% of NON-TRIVIAL rows to match.
    private static func verifyOverlap(a: PixelBuffer, b: PixelBuffer,
                                        contentOverlap: Int, headerHeight: Int,
                                        sampleCols: [Int]) -> Bool {
        let h = a.height
        var goodRows = 0, checkedRows = 0

        // Check ~30 rows spread across the overlap
        let rowStep = max(1, contentOverlap / 30)
        for i in stride(from: 0, to: contentOverlap, by: rowStep) {
            let rowA = h - contentOverlap + i
            let rowB = headerHeight + i
            guard rowA >= 0 && rowA < h && rowB >= 0 && rowB < b.height else { continue }

            let trivial = rowIsTrivial(buf: a, row: rowA, sampleCols: sampleCols)
            let matches = rowMatches(a: a, rowA: rowA, b: b, rowB: rowB, sampleCols: sampleCols)

            if !trivial {
                checkedRows += 1
                if matches { goodRows += 1 }
            }
        }

        // Need at least 5 non-trivial rows checked, and >= 70% match
        return checkedRows >= 5 && goodRows * 100 / checkedRows >= 70
    }

    // MARK: - Render

    private static func renderStitched(frames: [CGImage], overlaps: [Int], scale: CGFloat) -> NSImage? {
        let w = frames[0].width

        var totalH = frames[0].height
        for i in 1..<frames.count {
            let ov = max(0, min(overlaps[i - 1], frames[i].height - 20))
            totalH += frames[i].height - ov
        }

        NSLog("[Stitcher] rendering: \(w)x\(totalH)")

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: totalH, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        // CG context origin is bottom-left
        // First frame goes at the top (y = totalH - frame height)
        var y = totalH - frames[0].height
        ctx.draw(frames[0], in: CGRect(x: 0, y: y, width: w, height: frames[0].height))

        for i in 1..<frames.count {
            let ov = max(0, min(overlaps[i - 1], frames[i].height - 20))
            let keepHeight = frames[i].height - ov

            // CGImage.cropping: origin is top-left, y increases downward
            // Skip top `ov` rows
            if keepHeight > 0, let cropped = frames[i].cropping(to: CGRect(x: 0, y: ov, width: w, height: keepHeight)) {
                y -= keepHeight
                ctx.draw(cropped, in: CGRect(x: 0, y: y, width: cropped.width, height: cropped.height))
            }
        }

        guard let result = ctx.makeImage() else { return nil }
        return NSImage(cgImage: result, size: NSSize(width: CGFloat(w) / scale, height: CGFloat(totalH) / scale))
    }

    // MARK: - Fallback

    private static func simpleConcatenate(_ frames: [CGImage], scale: CGFloat) -> NSImage? {
        let w = frames[0].width
        let totalH = frames.reduce(0) { $0 + $1.height }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: totalH, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        var y = totalH
        for f in frames { y -= f.height; ctx.draw(f, in: CGRect(x: 0, y: y, width: w, height: f.height)) }
        guard let r = ctx.makeImage() else { return nil }
        return NSImage(cgImage: r, size: NSSize(width: CGFloat(w) / scale, height: CGFloat(totalH) / scale))
    }

    // MARK: - Identity check

    static func framesIdentical(_ a: CGImage, _ b: CGImage) -> Bool {
        guard a.width == b.width, a.height == b.height else { return false }
        guard let ba = toPixelBuffer(a), let bb = toPixelBuffer(b) else { return false }

        let w = ba.width
        let colStep = max(1, w / 20)
        var diffs = 0, total = 0

        for row in [a.height / 5, a.height * 2 / 5, a.height / 2, a.height * 3 / 5, a.height * 4 / 5] {
            for col in stride(from: w / 10, to: w * 9 / 10, by: colStep) {
                let (r1, g1, b1) = ba.pixel(row: row, col: col)
                let (r2, g2, b2) = bb.pixel(row: row, col: col)
                total += 1
                if abs(Int(r1) - Int(r2)) > 5 || abs(Int(g1) - Int(g2)) > 5 || abs(Int(b1) - Int(b2)) > 5 { diffs += 1 }
            }
        }

        return total > 0 && diffs * 100 / total < 3
    }
}
