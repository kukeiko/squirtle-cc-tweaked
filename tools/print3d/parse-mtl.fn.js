import { existsSync } from "fs";
import { readFile } from "fs/promises"

/**
 * @param {string} objFilename 
 * @returns {Promise<Map<string, { r: number; g: number; b: number }>}
 */
export async function parseMtl(objFilename) {
    const pos = objFilename.lastIndexOf(".");
    const mtlFilename = objFilename.substring(0, pos < 0 ? file.length : pos) + ".mtl";

    if (!existsSync(mtlFilename)) {
        return new Map();
    }

    const contents = (await readFile(mtlFilename, { encoding: "utf-8" })).toString();

    /** @type {string[][]} */
    const groups = contents.split("\n").reduce((groups, line) => {
        if (line.includes("Kd ")) {
            groups[groups.length - 1].push(line.replace("\t", ""));
        } else if (line.includes("newmtl")) {
            groups.push([line]);
        }

        return groups;
    }, []);

    const entries = groups.map(lines => {
        const nameLine = lines.find(line => line.includes("newmtl"));
        const diffuseLine = lines.find(line => line.includes("Kd "));

        if (!nameLine || !diffuseLine) {
            throw new Error("did not find name or diffuse line")
        }

        const name = nameLine.split("newmtl ")[1];
        const [r, g, b] = diffuseLine.split("Kd ")[1].split(" ").map(val => parseFloat(val) * 255);

        return [name, { r, g, b }]
    });

    return new Map(entries);
}

