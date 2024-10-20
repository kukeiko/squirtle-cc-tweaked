import { closest } from "color-diff";

/**
 * @param {Point[]} points 
 * @param {BlockColor[]} blockColors 
 */
export function assignBlockColors(points, blockColors) {
    const remappedBlockColors = blockColors.map(blockColor => ({ B: blockColor.b, G: blockColor.g, R: blockColor.r }));

    for (const point of points) {
        const best = closest({ B: point.b, G: point.g, R: point.r }, remappedBlockColors);
        const blockColor = blockColors.find(blockColor => blockColor.b === best.B && blockColor.g === best.G && blockColor.r === best.R);

        point.block = blockColor?.name ?? "minecraft:stone";
    }
}
