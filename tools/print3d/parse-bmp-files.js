import { join, parse } from "path";
import { decode, encode } from "bmp-js"
import { readFile, writeFile } from "fs/promises"
import { fileExists } from "../utils.js"

/**
 * @param {string} objFilename
 * @param {Point[]} points 
 * @param {Dimensions} dimensions 
 */
export async function parseBmpFiles(objFilename) {
    const { dir, name } = parse(objFilename);
    const nameWithoutY = name.split("_").slice(0, -1).join("_");

    /** @type {Point[]} */
    const points = [];
    let y = 0;

    while (true) {
        const filename = `${nameWithoutY}_${y}.bmp`;
        // console.log("🌵", filename);
        const exists = await fileExists(join(dir, filename));

        if (!exists) {
            break;
        }

        const file = await readFile(join(dir, filename));
        const imgData = decode(file);
        let offset = 0;

        for (let z = 0; z < imgData.height; z++) {
            for (let x = 0; x < imgData.width; x++) {
                const [a, b, g, r] = [imgData.data[offset++], imgData.data[offset++], imgData.data[offset++], imgData.data[offset++]];

                if (a !== 255 && b !== 255 && g !== 255 && r !== 255) {
                    points.push({ x, y, z: z - (imgData.height - 1), b, g, r })
                }
            }
        }

        y++;
    }

    return points;
}