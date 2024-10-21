/**
 * @param {PointColumn} column 
 * @return {Blueprint}
 */
export function toBlueprint(column) {
    const palette = Array.from(column.blocks.keys());
    /** @type {number[]} */
    const points = [];

    column.points.reduce((previous, current) => {
        if (!previous) {
            points.push(current.x, current.y, current.z, palette.findIndex(block => block === current.block) + 1);
            return current;
        }

        let [x, y, z] = [current.x - previous.x, current.y - previous.y, current.z - previous.z];
        points.push(x, y, z, palette.findIndex(block => block === current.block) + 1);

        return current;
    }, undefined)

    /** @type {Blueprint} */
    const blueprint = {
        x: column.x,
        fuel: column.fuel,
        shulkers: column.shulkers,
        blocks: Object.fromEntries(column.blocks.entries()),
        palette,
        points
    }

    return blueprint;
}