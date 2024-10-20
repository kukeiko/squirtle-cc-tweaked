import { readFile } from "fs/promises";

/**
 * @returns {Promise<string[]>}
 */
export async function parseBlockPalette(filePath) {
    const blockPalette = JSON.parse((await readFile(filePath, { encoding: "utf-8" })).toString());

    if (!Array.isArray(blockPalette)) {
        throw new Error(`not an array`);
    }

    blockPalette.forEach((entry, index) => {
        if (typeof (entry) !== "string") {
            throw new Error(`entry at index ${index} is not a string`);
        }
    })

    return blockPalette;
}