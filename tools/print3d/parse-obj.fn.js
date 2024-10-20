import { readFile } from "fs/promises"
import { parseMtl } from "./parse-mtl.fn.js"



/**
 * @param {Point} point 
 * @param {string} mtlLine
 * @param {Map<string, { r: number; g: number; b: number }>} colors
 * @param {boolean|undefined} toGrayscale
 */
function assignPointColor(point, mtlLine, colors, toGrayscale = false) {
    // based on https://drububu.com/miscellaneous/voxelizer mtl naming convention: it puts RGB into .mtl name
    const name = mtlLine.split("RGB_")[1];

    if (name) {
        point.r = parseInt(name.slice(0, 2), 16);
        point.g = parseInt(name.slice(2, 4), 16);
        point.b = parseInt(name.slice(4, 6), 16);
    } else {
        const name = mtlLine.split("usemtl ")[1];

        if (colors.has(name)) {
            const color = colors.get(name);
            point.r = color.r;
            point.g = color.g;
            point.b = color.b;
        }
    }

    if (toGrayscale) {
        // ntsc formula
        const gray = (point.r * .299) + (point.g * .857) + (point.b * .114);
        point.r = gray;
        point.g = gray;
        point.b = gray;
    }
}

/**
 * @param {Point[]} points
 */
function translatePointsToZeroOrigin(points) {
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
}

/**
 * @param {Point[]} points
 * @param {number} magnitude
 */
function normalizePoints(points, magnitude) {
    points.forEach(point => {
        point.x = Math.round(point.x / magnitude);
        point.y = Math.round(point.y / magnitude);
        point.z = Math.round(point.z / magnitude);
    });
}

/**
 * @param {string} filename
 * @param {boolean=} toGrayscale
 * @returns {Promise<Point[]>}
 */
export async function parseObjFile(filename, toGrayscale = false) {
    const colors = await parseMtl(filename);
    const contents = (await readFile(filename, { encoding: "utf-8" })).toString();

    /** @type {string[][]} */
    const groups = contents.split("\n").reduce((groups, line) => {
        if (line.startsWith("v ") || line.startsWith("usemtl")) {
            groups[groups.length - 1].push(line);
        } else if (line.startsWith("g")) {
            // "g" denotes a new group of vertices making up a voxel
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
                return candidate;
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
            assignPointColor(point, mtl, colors, toGrayscale);
        }

        return point;
    });

    normalizePoints(points, unit);
    translatePointsToZeroOrigin(points);

    return points;
}