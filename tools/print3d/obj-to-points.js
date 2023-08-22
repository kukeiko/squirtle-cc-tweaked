import { readFile, writeFile } from "fs/promises"
import { inspect } from "util";
import { parseObjFile } from "./parse-obj.js";

const objFilename = process.argv[2];
const slices = parseInt(process.argv[3] ?? "1");
const colorFilename = process.argv[4];
const toGrayscale = process.argv[5] == "true";

const { points, unit } = await parseObjFile(objFilename, toGrayscale);

if (colorFilename) {
    /** @type {Block[]} */
    const blockColors = JSON.parse((await readFile(colorFilename, { encoding: "utf-8" })).toString());

    /**
     * @param {Point} point 
     * @param {Block} block 
     * @returns {number}
     */
    function deviation(point, block) {
        return Math.abs(block.r - point.r) + Math.abs(block.g - point.g) + (Math.abs(block.b - point.b));
    }

    points
        // .filter(point => point.r !== undefined && point.g !== undefined && point.b !== undefined)
        .forEach(point => {
            const block = blockColors.reduce((best, candidate) => {
                if (!best || deviation(point, candidate) < deviation(point, best)) {
                    return candidate;
                }

                return best
            }, undefined);

            if (block) {
                point.block = block.name;
            }
        })
}

const offsetBy = points.reduce((offset, value) => {
    if (!offset) {
        return value;
    }

    if (value.x < offset.x) {
        offset.x = value.x;
    }

    if (value.y < offset.y) {
        offset.y = value.y;
    }

    if (value.z > offset.z) {
        offset.z = value.z;
    }

    return offset;
}, { x: Infinity, y: Infinity, z: -Infinity })

points.forEach(point => {
    point.x -= offsetBy.x;
    point.y -= offsetBy.y;
    point.z -= offsetBy.z;
});

points.forEach(point => {
    point.x = Math.round(point.x / unit);
    point.y = Math.round(point.y / unit);
    point.z = Math.round(point.z / unit);
});

const dimensions = points.reduce((dimensions, point) => {
    if (point.x > dimensions.x) {
        dimensions.x = point.x;
    }

    if (point.y > dimensions.y) {
        dimensions.y = point.y;
    }

    if (point.z < dimensions.z) {
        dimensions.z = point.z;
    }

    return dimensions;
}, { x: 0, y: 0, z: 0 });

dimensions.x += 1;
dimensions.y += 1;
dimensions.z *= -1;
dimensions.z += 1;

console.log("dimensions:", dimensions);

/** @type {Point[][]} */
const slicedPoints = [];
const sliceWidth = Math.floor(dimensions.x / slices);

for (let i = 0; i < slices; i++) {
    const pointsOfSlice = points.filter(point => {
        if(i == slices - 1) {
            return (point.x >= i * sliceWidth);
        } else {
            return (point.x >= i * sliceWidth) && point.x < ((i + 1) * sliceWidth)
        }
    });

    pointsOfSlice.forEach(point => {
        point.x -= i * sliceWidth;
    });

    slicedPoints.push(pointsOfSlice);
}

/**
 * @param {Point[]} points 
 * @param {string} objFilename
 * @param {number=} x
 */
async function exportPoints(points, objFilename, x) {
    points.sort((a, b) => {
        if (a.y !== b.y) {
            return a.y - b.y;
        } else if (a.z !== b.z) {
            return a.z - b.z;
        } else if (a.x !== b.x) {
            return a.x - b.x;
        }

        throw new Error(`duplicate point: ${JSON.stringify(a)}`)
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
    const snakedLayers = layers.map((layerY, i) => i % 2 == 0 ? layerY.map((layerZ, i) => i % 2 == 0 ? layerZ : layerZ.reverse()) : layerY.reverse().map((layerZ, i) => i % 2 == 0 ? layerZ : layerZ.reverse()));



    /** @type {[number, number, number, string]} */
    const compacted = snakedLayers.flat(2).map(point => {
        const compact = [point.x, point.y, point.z];

        if (point.block) {
            compact.push(point.block);
        }

        return compact;
    });

    const pos = objFilename.lastIndexOf(".");
    const outFilename = objFilename.substring(0, pos < 0 ? file.length : pos) + (x === undefined ? ".t3d" : "_" + (x + 1) + ".t3d");
    // console.log(unit);
    // console.log(inspect(compacted, { depth: null }));

    /** @type {Map<string,number>} */
    const stats = new Map();

    points.filter(point => point.block !== undefined).forEach((point) => {
        stats.set(point.block, (stats.get(point.block) ?? 0) + 1);
    });

    console.log(outFilename);
    console.log(stats);

    await writeFile(outFilename, JSON.stringify(compacted));
}

slicedPoints.forEach(async (slicedPoints, i) => {
    exportPoints(slicedPoints, objFilename, i * sliceWidth);
});