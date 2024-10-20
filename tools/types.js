/**
 * @typedef {Object} Point
 * @property {number} x
 * @property {number} y
 * @property {number} z
 * @property {number} r
 * @property {number} g
 * @property {number} b
 * @property {string=} block
 */

/**
 * @typedef {Object} PointColumn
 * @property {number} x
 * @property {Point[]} points
 * @property {Map<string, number>} blocks
 * @property {number} fuel
 * @property {number} shulkers
 */

/**
 * @typedef {Object} Dimensions
 * @property {number} x
 * @property {number} y
 * @property {number} z
 */

/**
 * @typedef BlockColor
 * @property {string} name
 * @property {number} r
 * @property {number} g
 * @property {number} b
 **/

/**
 * @typedef Blueprint
 * @property {number} x
 * @property {number} fuel
 * @property {number} shulkers
 * @property {Record<string, number>} blocks
 * @property {string[]} palette
 * @property {[number, number, number, number][]} points
 */