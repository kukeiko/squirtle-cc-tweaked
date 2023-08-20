import { readFile, writeFile } from "fs/promises"
import { inspect } from "util";

const objFile = process.argv[2];
const contents = (await readFile(objFile, { encoding: "utf-8" })).toString();
let unit = 0;

const groups = contents.split("\n").reduce((groups, line) => {
    if (line.startsWith("v")) {
        groups[groups.length - 1].push(line);
    } else {
        groups.push([]);
    }

    return groups;
}, []);

const coordinates = groups
    .map(group => group
        .filter(line => line.startsWith("v "))
        .map(line => {
            const [x, y, z] = line.split(" ").slice(1).map(point => parseFloat(point));

            return { x, y, z };
        })
        .reduce((smallest, candidate) => {
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
    ).filter(point => point !== undefined);

const offsetBy = coordinates.reduce((offset, value) => {
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

coordinates.forEach(point => {
    point.x -= offsetBy.x;
    point.y -= offsetBy.y;
    point.z -= offsetBy.z;
});

coordinates.forEach(point => {
    point.x = Math.round(point.x / unit);
    point.y = Math.round(point.y / unit);
    point.z = Math.round(point.z / unit);
});

coordinates.sort((a, b) => {
    if (a.y !== b.y) {
        return a.y - b.y;
    } else if (a.z !== b.z) {
        return a.z - b.z;
    } else if (a.x !== b.x) {
        return a.x - b.x;
    }

    throw new Error(`duplicate point: ${JSON.stringify(a)}`)
});

const { layers } = coordinates.reduce((acc, point) => {
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

const snakedLayers = layers.map((layerY, i) => i % 2 == 0 ? layerY.map((layerZ, i) => i % 2 == 0 ? layerZ : layerZ.reverse()) : layerY.reverse().map((layerZ, i) => i % 2 == 0 ? layerZ : layerZ.reverse()));
const compacted = snakedLayers.flat(2).map(point => [point.x, point.y, point.z]);
const pos = objFile.lastIndexOf(".");
const outFilename = objFile.substring(0, pos < 0 ? file.length : pos) + ".t3d"
console.log(unit);
console.log(inspect(compacted, { depth: null }));
console.log(outFilename);
await writeFile(outFilename, JSON.stringify(compacted));