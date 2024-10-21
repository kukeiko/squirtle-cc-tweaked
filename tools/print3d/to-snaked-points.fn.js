import { getDimensions } from "./get-dimensions.fn.js"

/**
 * @param {Point[]} points 
 * @returns {Point[]}
 */
function sortPointsByYZX(points) {
    return points = points.slice().sort((a, b) => {
        if (a.y !== b.y) {
            return a.y - b.y;
        } else if (a.z !== b.z) {
            return b.z - a.z;
        } else if (a.x !== b.x) {
            return a.x - b.x;
        }
    });
}


/**
 * @param {Point[]} points 
 * @returns {Point[]}
 */
function sortPointsByYXZ(points) {
    return points = points.slice().sort((a, b) => {
        if (a.y !== b.y) {
            return a.y - b.y;
        } else if (a.x !== b.x) {
            return a.x - b.x;
        } else if (a.z !== b.z) {
            return b.z - a.z;
        }
    });
}

/**
 * @param {Point[]} points 
 * @returns {Point[]}
 */
export function toSnakedPoints(points) {
    const dimensions = getDimensions(points);

    if (dimensions.x > dimensions.z) {
        points = sortPointsByYZX(points);
    } else {
        points = sortPointsByYXZ(points);
    }

    /** @type { {layers: Point[] }} */
    const { layers } = points.reduce((acc, point) => {
        let [value, previousValue] = dimensions.x > dimensions.z ? [point.z, acc.previous.z] : [point.x, acc.previous.x];

        if (dimensions.x > dimensions.z) {
            [value, previousValue] = [point.z, acc.previous.z];
        }

        if (point.y !== acc.previous.y) {
            acc.layers.push([[]]);
        } else if (value !== previousValue) {
            acc.layers[acc.layers.length - 1].push([]);
        }

        const layerY = acc.layers[acc.layers.length - 1];
        const subLayer = layerY[layerY.length - 1];

        subLayer.push(point);
        acc.previous = point;

        return acc;
    }, { layers: [], previous: { x: Infinity, y: Infinity, z: Infinity } });

    /** @type {Point[][]} */
    const snakedLayers = layers.map((layerY, i) => {
        if (i % 2 == 0) {
            return layerY.map((subLayer, i) => i % 2 == 0 ? subLayer : subLayer.reverse())
        } else {
            return layerY.reverse().map((subLayer, i) => i % 2 == 0 ? subLayer : subLayer.reverse())
        }
    });

    return snakedLayers.flat(2);
}