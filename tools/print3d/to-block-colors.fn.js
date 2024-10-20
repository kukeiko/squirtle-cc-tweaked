import { join } from "path"
import { readFile, readdir } from "fs/promises"
import { getAverageColor } from "fast-average-color-node";

/**
 * @param {string[]} blockPalette 
 * @param {string} unpackedMinecraftFolder 
 * @returns {Promise<BlockColor[]>}
 */
export async function toBlockColors(blockPalette, unpackedMinecraftFolder) {
    const blockFolder = join(unpackedMinecraftFolder, "assets/minecraft/models/block");
    const textureFolder = join(unpackedMinecraftFolder, "assets/minecraft/textures/block");
    // we use azalea leaves as a color drop-in for other leaves as they are all grey
    const azaleaLeavesColor = await getAverageColor(join(textureFolder, "azalea_leaves.png"));
    /** @type {BlockColor[]} */
    const blocks = [];

    for (const jsonFile of await readdir(blockFolder)) {
        /** @type {{ parent: string, textures: { all?: string; side?: string; } }} */
        const json = JSON.parse((await readFile(join(blockFolder, jsonFile))).toString());
        /** @type {string} */
        const name = jsonFile.replace(".json", "");

        if (json.parent !== "minecraft:block/cube_all" && json.parent !== "minecraft:block/leaves" && json.parent !== "minecraft:block/cube_column") {
            continue;
        }

        if (blockPalette.length && !blockPalette.find(block => name.match(block))) {
            continue;
        }

        const color = name.includes("leaves") ? azaleaLeavesColor : await getAverageColor(join(textureFolder, `${(json.textures.all ?? json.textures.side).replace("minecraft:block/", "")}.png`));

        const [r, g, b] = color.value;
        blocks.push({ name: `minecraft:${name}`, r, g, b });
    }

    return blocks;
}