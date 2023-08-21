import { join } from "path"
import { readFile, readdir, writeFile } from "fs/promises"
import { inspect } from "util";
import { getAverageColor } from "fast-average-color-node";

const versionFolder = process.argv[2];
const blockFolder = join(versionFolder, "assets/minecraft/models/block");
const textureFolder = join(versionFolder, "assets/minecraft/textures/block");
const outfilePath = "./blocks-to-rgb.json";

/**
 * @typedef Block
 * @property {string} name
 * @property {number} r
 * @property {number} g
 * @property {number} b
 **/

/** @type {Block[]} */
const blocks = [];

const blacklist = [
    "concrete_powder",
    "ore",
    /^sand$/,
    /^red_sand$/,
    "glass",
    "ice",
    "sponge",
    "spawner",
    "redstone",
    "leaves",
    "coral",
    "brown_mushroom",
    "mushroom_stem",
    "inventory",
    "budding",
    "coal_block",
    "cracked",
    "obsidian",
    "diamond_block",
    "netherite_block",
    "gold_block",
    "iron_block",
    "emerald_block",
    "glowstone",
    "gravel",
    "note_block",
    "gilded_blackstone",
    "blackstone",
    "sea_lantern",
    "structure_block",
    "bedrock",
    // temp for grayscale using less blocks
    "nether",
    "gray_terracotta",
    "white_terracotta",
    "brown_terracotta",
    "wool",
    "chiseled",
    "bricks",
    "smooth_stone",
    "tiles",
    "clay",
    "purpur",
    "prismarine",
    "planks",
    "black_terracotta",
    "terracotta",
    "concrete",
    "soul"
];

for (const jsonFile of await readdir(blockFolder)) {
    /** @type {{ parent: {string}, textures: { all: {string} } }} */
    const json = JSON.parse((await readFile(join(blockFolder, jsonFile))).toString());
    const name = jsonFile.replace(".json", "");

    if (json.parent !== "minecraft:block/cube_all") {
        continue;
    }

    if (blacklist.some(blacklisted => name.match(blacklisted))) {
        console.log("❌", name);
    } else {
        console.log("✔️", name);
        const color = await getAverageColor(join(textureFolder, `${json.textures.all.replace("minecraft:block/", "")}.png`));
        const [r, g, b] = color.value;
        blocks.push({ name: `minecraft:${name}`, r, g, b });
    }
}

console.log(inspect(blocks, { maxArrayLength: null, depth: null }));

await writeFile(outfilePath, JSON.stringify(blocks));