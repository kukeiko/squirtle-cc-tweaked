import { readFile } from "fs/promises"

/**
 * @param {string} filename
 * @param {boolean=} toGrayscale
 * @returns {Promise<{points: Point[]; unit: number}>}
 */
export async function parseObjFile(filename, toGrayscale = false) {
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

                // [todo] move grayscaling to turtle app
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