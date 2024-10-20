import { toSnakedPoints } from "./to-snaked-points.fn.js";

/**
 * @param {Point[]} points
 * @param {number} x
 */
function toPointColumn(points, x) {
    /** @type {PointColumn} */
    const column = {
        blocks: new Map(),
        x: x,
        points: points.filter(point => point.x === x),
        fuel: 0,
        shulkers: 0
    };

    for (const point of column.points) {
        column.blocks.set(point.block, (column.blocks.get(point.block) ?? 0) + 1);
    }

    return column;
}

/**
 * @param {PointColumn[]} columns 
 * @returns {Map<string, number>}
 */
function mergeColumnBlocks(columns) {
    const blocks = new Map();

    for (const column of columns) {
        for (const [block, quantity] of column.blocks.entries()) {
            blocks.set(block, (blocks.get(block) ?? 0) + quantity);
        }
    }

    return blocks;
}

/**
 * @param {PointColumn[]} columns 
 * @returns {PointColumn}
 */
function mergeColumns(columns) {
    const x = Math.min(...columns.map(column => column.x));
    const points = columns.flatMap(column => column.points);

    /** @type {PointColumn} */
    const column = {
        x: x,
        blocks: mergeColumnBlocks(columns),
        points: toSnakedPoints(points),
        fuel: countFuel(columns),
        shulkers: countShulkers(columns)
    };

    return column
}


/**
 * @param {PointColumn[]} columns
 * @returns {number}
 */
function countStacks(columns) {
    const blocks = mergeColumnBlocks(columns);
    let numStacks = 0;

    for (const quantity of blocks.values()) {
        numStacks += Math.ceil(quantity / 64);
    }

    return numStacks;
}

/**
 * @param {PointColumn[]} columns
 * @returns {number}
 */
function countShulkers(columns) {
    const numStacks = countStacks(columns);

    // shulkers have 27 slots, but we want to leave one open so that turtle does not have to temporarily
    // load one item from the shulker to its inventory to free up the shulker's first slot
    return Math.ceil(numStacks / 26);
}


/**
 * @param {Point} a 
 * @param {Point} b 
 * @returns {number}
 */
function manhattan(a, b) {
    return Math.abs(b.x - a.x) + Math.abs(b.y - a.y) + Math.abs(b.z - a.z)
}

/**
 * @param {PointColumn[]} columns
 * @returns {number}
 */
function countFuel(columns) {
    const snakedPoints = toSnakedPoints(columns.flatMap(column => column.points));

    if (snakedPoints.length < 2) {
        return 0;
    }

    /** @type {Point} */
    const homePoint = { x: 0, y: 0, z: 0 }

    return snakedPoints.reduce((previous, current) => {
        return { point: current, fuel: previous.fuel + manhattan(previous.point, current) };
    }, { point: homePoint, fuel: 0 }).fuel;
}

/**
 * @param {PointColumn} column 
 * @param {number} maxFuel
 * @param {number} maxShulkers
 */
function assertColumnResources(column, maxShulkers, maxFuel) {
    const requiredShulkers = countShulkers([column]);

    if (requiredShulkers > maxShulkers) {
        throw new Error(`encountered a single y column that itself already exceeds max. number of shulkers allowed (max: ${maxShulkers}, requires: ${requiredShulkers})`);
    }

    const requiredFuel = countFuel([column]);

    if (requiredFuel > maxFuel) {
        throw new Error(`encountered a single y column that itself already exceeds max. fuel allowed (max: ${maxFuel}, requires: ${requiredFuel})`);
    }
}

/**
 * @param {Point[]} points
 * @param {Dimensions} dimensions
 * @param {number=} maxShulkers
 * @param {number=} maxFuel
 * @returns {PointColumn[]}
 */
export function toColumns(points, dimensions, maxShulkers = 1, maxFuel = 19000) {
    /** @type {PointColumn[]} */
    const columns = [];

    for (let x = 0; x < dimensions.x; x++) {
        columns.push(toPointColumn(points, x));
    }

    /** @type {PointColumn[][]} */
    const initialColumnGroups = [[]];

    const columnGroups = columns.reduce((columnGroups, column) => {
        assertColumnResources(column, maxShulkers, maxFuel);
        const candidateGroup = [...columnGroups[columnGroups.length - 1], column];

        if (countShulkers(candidateGroup) > maxShulkers || countFuel(candidateGroup) > maxFuel) {
            columnGroups.push([]);
        }

        columnGroups[columnGroups.length - 1].push(column);

        return columnGroups;
    }, initialColumnGroups)

    return columnGroups.map(columnGroup => mergeColumns(columnGroup));
}