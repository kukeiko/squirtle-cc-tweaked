/**
 * @param {Point[]} points 
 * @returns {Point[]}
 */
export function toSnakedPoints(points) {
    points = points.slice().sort((a, b) => {
        if (a.y !== b.y) {
            return a.y - b.y;
        } else if (a.z !== b.z) {
            return a.z - b.z;
        } else if (a.x !== b.x) {
            return a.x - b.x;
        }

        throw new Error(`duplicate point: ${JSON.stringify(a)}`); // [todo] should be thrown or filtered out in parse-obj
    });

    /** @type { {layers: Point[] }} */
    const { layers } = points.reduce((acc, point) => {
        if (point.y !== acc.previous.y) {
            acc.layers.push([[]]);
        } else if (point.z !== acc.previous.z) {
            acc.layers[acc.layers.length - 1].push([]);
        }

        const layerY = acc.layers[acc.layers.length - 1];
        const layerZ = layerY[layerY.length - 1];

        layerZ.push(point);
        acc.previous = point;

        return acc;
    }, { layers: [], previous: { x: Infinity, y: Infinity, z: Infinity } });

    /** @type {Point[][]} */
    const snakedLayers = layers.map((layerY, i) => {
        if (i % 2 == 0) {
            return layerY.map((layerZ, i) => i % 2 == 0 ? layerZ : layerZ.reverse())
        } else {
            return layerY.reverse().map((layerZ, i) => i % 2 == 0 ? layerZ : layerZ.reverse())
        }
    });

    return snakedLayers.flat(2);
}