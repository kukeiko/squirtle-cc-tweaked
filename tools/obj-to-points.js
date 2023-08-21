import { readFile, writeFile } from "fs/promises"
import { inspect } from "util";

/**
 * @typedef {Object} Point
 * @property {number} x
 * @property {number} y
 * @property {number} z
 * @property {number} r
 * @property {number} g
 * @property {number} b
 * @property {string=} block
 */

/**
 * @typedef Block
 * @property {string} name
 * @property {number} r
 * @property {number} g
 * @property {number} b
 **/

/**
 * @param {string} filename
 * @param {boolean=} toGrayscale
 * @returns {Promise<{points: Point[]; unit: number}>}
 */
async function parseObjFile(filename, toGrayscale = false) {
    const contents = (await readFile(filename, { encoding: "utf-8" })).toString();

    /** @type {string[][]} */
    const groups = contents.split("\n").reduce((groups, line) => {
        if (line.startsWith("v ") || line.startsWith("usemtl")) {
            groups[groups.length - 1].push(line);
        } else if (line.startsWith("g")) {
            groups.push([]);
        }

        return groups;
    }, []);

    let unit = 0;

    const points = groups.map(lines => {
        /** @type {Point} */
        const point = lines.filter(line => line.startsWith("v ")).map(line => {
            const [x, y, z] = line.split(" ").slice(1).map(point => parseFloat(point));

            return { x, y, z, r: 0, g: 0, b: 0 };
        }).reduce((smallest, candidate) => {
            if (!smallest) {
                return candidate
            }

            if (candidate.x <= smallest.x && candidate.y <= smallest.y && candidate.z <= smallest.z) {
                if (!unit) {
                    if (candidate.x !== smallest.x) {
                        unit = Math.abs(candidate.x - smallest.x);
                    } else if (candidate.y !== smallest.y) {
                        unit = Math.abs(candidate.y - smallest.y);
                    } else if (candidate.z !== smallest.z) {
                        unit = Math.abs(candidate.z - smallest.z);
                    }
                }

                return candidate;
            }

            return smallest;
        }, undefined)

        const mtl = lines.find(line => line.startsWith("usemtl"));

        if (mtl) {
            // based on https://drububu.com/miscellaneous/voxelizer mtl naming convention: it puts RGB into .mtl name
            const name = mtl.split("RGB_")[1];

            if (name) {
                point.r = parseInt(name.slice(0, 2), 16);
                point.g = parseInt(name.slice(2, 4), 16);
                point.b = parseInt(name.slice(4, 6), 16);

                if (toGrayscale) {
                    // ntsc formula
                    const gray = (point.r * .299) + (point.g * .857) + (point.b * .114);
                    point.r = gray;
                    point.g = gray;
                    point.b = gray;
                }
            }
        }

        return point;
    });

    return { points, unit }
}

let toGrayscale = true;
const objFilename = process.argv[2];
const { points, unit } = await parseObjFile(objFilename, toGrayscale);

if (process.argv[3]) {
    /** @type {{default: Block[]}} */
    const { default: blockColors } = await import(process.argv[3], { assert: { type: "json" } });

    console.log(blockColors);
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
const compacted = snakedLayers.flat(2).map(point => [point.x, point.y, point.z, point.block]);
const pos = objFilename.lastIndexOf(".");
const outFilename = objFilename.substring(0, pos < 0 ? file.length : pos) + ".t3d"
console.log(unit);
console.log(inspect(compacted, { depth: null }));
console.log(outFilename);

/** @type {Map<string,number>} */
const stats = new Map();

points.filter(point => point.block !== undefined).forEach((point) => {
    stats.set(point.block, (stats.get(point.block) ?? 0) + 1);
});

console.log(stats);

await writeFile(outFilename, JSON.stringify(compacted));
