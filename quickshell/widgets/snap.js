.pragma library

// Where a desktop widget lands when you let go of it: lined up with the screen edges
// (a margin in from them) or with another widget's edges (side by side with a gap, or
// sharing an edge), whichever is closest. Too far from all of those, it rounds to a grid.
//   x, y, w, h : where it was dropped, and its size
//   W, H       : the screen
//   top, bottom: room the bar takes at the top and the dock at the bottom
//   others     : the other widgets, [{ x, y, w, h }]
const MARGIN = 24     // from the screen edges
const GAP = 12        // between widgets, like on macOS
const PULL = 48       // how close counts as "meant to line up"
const GRID = 12

function nearest(v, list) {
    let best = null
    for (const c of list) {
        if (Math.abs(c - v) <= PULL && (best === null || Math.abs(c - v) < Math.abs(best - v))) best = c
    }
    return best === null ? Math.round(v / GRID) * GRID : best
}

function snap(x, y, w, h, W, H, top, bottom, others) {
    const xs = [MARGIN, W - w - MARGIN]
    const ys = [top + MARGIN, H - h - bottom - MARGIN]
    for (const o of others) {
        // Side by side, or one above the other, with a gap
        xs.push(o.x + o.w + GAP, o.x - w - GAP)
        ys.push(o.y + o.h + GAP, o.y - h - GAP)
        // Sharing an edge (left, right, top or bottom lined up)
        xs.push(o.x, o.x + o.w - w)
        ys.push(o.y, o.y + o.h - h)
    }
    const nx = Math.max(0, Math.min(W - w, nearest(x, xs)))
    const ny = Math.max(0, Math.min(H - h, nearest(y, ys)))
    return { x: nx, y: ny }
}
