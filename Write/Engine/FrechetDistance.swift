import CoreGraphics

/// Discrete Frechet distance computation between two point sequences.
/// The Frechet distance respects the ordering/direction of curves,
/// so a backwards-drawn stroke will score poorly.
enum FrechetDistance {

    /// Computes the discrete Frechet distance between two point sequences.
    /// This is the minimum over all monotone reparameterizations of the maximum
    /// pointwise distance - it captures both shape and direction similarity.
    /// Uses an iterative (bottom-up) DP approach to avoid stack overflow on large inputs.
    static func compute(between p: [CGPoint], and q: [CGPoint]) -> CGFloat {
        let n = p.count
        let m = q.count
        guard n > 0, m > 0 else { return .infinity }

        let rows = UnsafeMutablePointer<CGFloat>.allocate(capacity: 2 * m)
        defer { rows.deallocate() }
        var previous = rows
        var current = rows + m

        p.withUnsafeBufferPointer { pBuffer in
            q.withUnsafeBufferPointer { qBuffer in
                guard let pBase = pBuffer.baseAddress, let qBase = qBuffer.baseAddress else {
                    return
                }
                var i = 0
                while i < n {
                    let pi = pBase[i]
                    var j = 0
                    while j < m {
                        let qj = qBase[j]
                        let dx = pi.x - qj.x
                        let dy = pi.y - qj.y
                        let d = (dx * dx + dy * dy).squareRoot()
                        var reach: CGFloat
                        if i == 0 && j == 0 {
                            reach = d
                        } else if i == 0 {
                            reach = current[j - 1]
                        } else if j == 0 {
                            reach = previous[0]
                        } else {
                            reach = previous[j]
                            if previous[j - 1] < reach {
                                reach = previous[j - 1]
                            }
                            if current[j - 1] < reach {
                                reach = current[j - 1]
                            }
                        }
                        current[j] = reach > d ? reach : d
                        j += 1
                    }
                    swap(&previous, &current)
                    i += 1
                }
            }
        }

        return previous[m - 1]
    }
}
