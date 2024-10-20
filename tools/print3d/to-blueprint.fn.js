/**
 * @param {PointColumn} column 
 * @return {Blueprint}
 */
export function toBlueprint(column) {
    const palette = Array.from(column.blocks.keys());

    /** @type {Blueprint} */
    const blueprint = {
        x: column.x,
        fuel: column.fuel,
        shulkers: column.shulkers,
        blocks: Object.fromEntries(column.blocks.entries()),
        palette,
        points: column.points.map(point => [point.x, point.y, point.z, palette.findIndex(block => block === point.block) + 1])
    }

    return blueprint;
}