import { join } from "path";
import { decode, encode } from "bmp-js"
import { readFile, writeFile } from "fs/promises"

/**
 * @param {string} directory
 * @param {string} name
 * @param {Point[]} points 
 * @param {Dimensions} dimensions 
 */
export async function exportBmp(directory, name, points, dimensions) {
    /**
     * @param {Point} point 
     * @returns {string}
     */
    const pointToKey = point => `${point.x}:${point.y}:${point.z}`;
    const pointsMap = new Map(points.map(point => [pointToKey(point), point]));

    for (let y = 0; y < dimensions.y; y++) {
        const buffer = Buffer.allocUnsafe(dimensions.z * dimensions.x * 4);
        let offset = 0;

        for (let z = 0; z < dimensions.z; z++) {
            for (let x = 0; x < dimensions.x; x++) {
                const key = pointToKey({ x, y, z: z - (dimensions.z - 1) });
                const point = pointsMap.get(key);
                const color = point ? [255, point.b, point.g, point.r] : [255, 255, 255, 255];

                color.forEach(channel => {
                    buffer.writeUInt8(channel, offset++);
                });
            }
        }

        await writeFile(join(directory, `${name}_${y}.bmp`), encode({ data: buffer, height: dimensions.z, width: dimensions.x }).data);
    }
}