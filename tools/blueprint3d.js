import { writeFile } from "fs/promises";
import { dirname, join, parse } from "path";
import { assignBlockColors } from "./print3d/assign-block-colors.fn.js";
import { getDimensions } from "./print3d/get-dimensions.fn.js";
import { parseBlockPalette } from "./print3d/parse-block-palette.fn.js";
import { parseObjFile } from "./print3d/parse-obj.fn.js";
import { toBlockColors } from "./print3d/to-block-colors.fn.js";
import { toBlueprint } from "./print3d/to-blueprint.fn.js";
import { toColumns } from "./print3d/to-columns.fn.js";
import { assertIsDirectory, assertIsFile, fileExists } from "./utils.js";
import { exportBmp } from "./print3d/export-bmp.js"
import { parseBmpFiles } from "./print3d/parse-bmp-files.js"

const objFilename = process.argv[2];
const unpackedMinecraftFolder = process.argv[3];
const maxShulkers = +(process.argv[4] ?? "12");

if (typeof (objFilename) !== "string" || !objFilename.length) {
    console.error(".obj file argument invalid or missing")
    process.exit();
}

if (typeof (unpackedMinecraftFolder) !== "string" || !unpackedMinecraftFolder.length) {
    console.error("unpacked minecraft folder argument invalid or missing")
    process.exit();
}

if (isNaN(maxShulkers) || maxShulkers < 1 || maxShulkers > 14) {
    console.error("maxShulkers must be a number in the range of [0, 14]")
    process.exit();
}

assertIsFile(objFilename);
assertIsDirectory(unpackedMinecraftFolder);

let isBmp = false;

if (parse(objFilename).ext === ".bmp") {
    isBmp = true;
    console.log("using .bmp as input");
}

const points = await (isBmp ? parseBmpFiles(objFilename) : parseObjFile(objFilename));
const dimensions = getDimensions(points);

await exportBmp(dirname(objFilename), parse(objFilename).name, points, dimensions);

console.log(`found ${points.length} voxels`);
console.log("dimensions:", dimensions);

const blockPaletteFilename = join(dirname(objFilename), "block-palette.json");

/** @type {string[]} */
let blockPalette = [];

if (await fileExists(blockPaletteFilename)) {
    try {
        blockPalette = await parseBlockPalette(blockPaletteFilename);
        console.log("using block-palette.json", blockPalette);
    } catch (error) {
        console.error(`could not parse block-palette.json: ${error.message}`);
        process.exit();
    }
}

const blockColors = await toBlockColors(blockPalette, unpackedMinecraftFolder);

blockColors.forEach(blockColor => {
    console.log("✔️ will use", blockColor.name);
});

assignBlockColors(points, blockColors);

const columns = toColumns(points, dimensions, maxShulkers);
const blueprints = columns.map(column => toBlueprint(column));
const totals = { blocks: 0, shulkers: 0, fuel: 0 };
/** @type {Record<string, number>} */
const blockTotals = {};

for await (const blueprint of blueprints) {
    totals.blocks += blueprint.points.length;
    totals.shulkers += blueprint.shulkers;
    totals.fuel += blueprint.fuel;

    for (const [block, quantity] of Object.entries(blueprint.blocks)) {
        blockTotals[block] = (blockTotals[block] || 0) + quantity
    }

    const blueprintFilename = join(dirname(objFilename), `${parse(objFilename).name}_${blueprint.x}.json`);
    await writeFile(blueprintFilename, JSON.stringify(blueprint));
}

console.log("total:", totals);

for (const [block, quantity] of Object.entries(blockTotals)) {
    console.log(` - ${quantity}x ${block} (${Math.ceil(quantity / 64)}x stacks)`);
}

const firstPoint = points.filter(point => point.y === 0).reduce((nearest, current) => {
    // [todo] when inverting z later on (making it positive), fix here
    if (current.z > nearest.z) {
        return current;
    } else if(current.z == nearest.z && current.x < nearest.x) {
        return current;
    }

    return nearest;
}, { x: Infinity, y: Infinity, z: -Infinity }) // [todo] when inverting z later on (making it positive), fix here


console.log("nearest:", firstPoint.x, firstPoint.y, firstPoint.z);