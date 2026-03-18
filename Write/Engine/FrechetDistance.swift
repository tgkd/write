import CoreGraphics

/// Discrete Frechet distance computation between two point sequences.
/// The Frechet distance respects the ordering/direction of curves,
/// so a backwards-drawn stroke will score poorly.
enum FrechetDistance {

    /// Computes the discrete Frechet distance between two point sequences.
    /// This is the minimum over all monotone reparameterizations of the maximum
    /// pointwise distance - it captures both shape and direction similarity.
    static func compute(between p: [CGPoint], and q: [CGPoint]) -> CGFloat {
        let n = p.count
        let m = q.count
        guard n > 0, m > 0 else { return .infinity }

        var dp = [[CGFloat]](repeating: [CGFloat](repeating: -1, count: m), count: n)

        func dist(_ i: Int, _ j: Int) -> CGFloat {
            let dx = p[i].x - q[j].x
            let dy = p[i].y - q[j].y
            return sqrt(dx * dx + dy * dy)
        }

        func frechet(_ i: Int, _ j: Int) -> CGFloat {
            if dp[i][j] >= 0 { return dp[i][j] }

            let d = dist(i, j)
            let result: CGFloat

            if i == 0 && j == 0 {
                result = d
            } else if i == 0 {
                result = max(frechet(0, j - 1), d)
            } else if j == 0 {
                result = max(frechet(i - 1, 0), d)
            } else {
                let prev = min(frechet(i - 1, j), frechet(i - 1, j - 1), frechet(i, j - 1))
                result = max(prev, d)
            }

            dp[i][j] = result
            return result
        }

        return frechet(n - 1, m - 1)
    }

    /// Iterative (bottom-up) Frechet distance - avoids stack overflow for large inputs.
    static func computeIterative(between p: [CGPoint], and q: [CGPoint]) -> CGFloat {
        let n = p.count
        let m = q.count
        guard n > 0, m > 0 else { return .infinity }

        var dp = [[CGFloat]](repeating: [CGFloat](repeating: 0, count: m), count: n)

        func dist(_ i: Int, _ j: Int) -> CGFloat {
            let dx = p[i].x - q[j].x
            let dy = p[i].y - q[j].y
            return sqrt(dx * dx + dy * dy)
        }

        for i in 0..<n {
            for j in 0..<m {
                let d = dist(i, j)
                if i == 0 && j == 0 {
                    dp[i][j] = d
                } else if i == 0 {
                    dp[i][j] = max(dp[0][j - 1], d)
                } else if j == 0 {
                    dp[i][j] = max(dp[i - 1][0], d)
                } else {
                    let prev = min(dp[i - 1][j], dp[i - 1][j - 1], dp[i][j - 1])
                    dp[i][j] = max(prev, d)
                }
            }
        }

        return dp[n - 1][m - 1]
    }
}
