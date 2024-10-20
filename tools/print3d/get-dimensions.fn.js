
/**
 * @param {Point[]} points 
 * @returns {Dimensions}
 */
export function getDimensions(points) {
    const dimensions = points.reduce((dimensions, point) => {
        if (point.x > dimensions.x) {
            dimensions.x = point.x;
        }

        if (point.y > dimensions.y) {
            dimensions.y = point.y;
        }

        if (point.z < dimensions.z) {
            dimensions.z = point.z;
        }

        return dimensions;
    }, { x: 0, y: 0, z: 0 });

    dimensions.x += 1;
    dimensions.y += 1;
    dimensions.z *= -1;
    dimensions.z += 1;

    return dimensions;
}
