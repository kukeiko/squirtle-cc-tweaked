import { stat } from "fs/promises";

/**
 * @param {string} filePath 
 * @returns {Promise<boolean>}
 */
export async function fileExists(filePath) {
    try {
        const fileStat = await stat(filePath);

        if (fileStat.isFile()) {
            return true;
        }
    } catch (error) {
        return false;
    }
}

export async function assertIsFile(filePath) {
    try {
        const objFileStat = await stat(filePath)

        if (!objFileStat.isFile()) {
            throw new Error("not a file");
        }
    } catch (error) {
        console.error(`could not open "${filePath}": ${error.message}`);
        process.exit();
    }
}

export async function assertIsDirectory(directoryPath) {
    try {
        const objFileStat = await stat(directoryPath)

        if (!objFileStat.isDirectory()) {
            throw new Error("not a directory");
        }
    } catch (error) {
        console.error(`could not open "${directoryPath}": ${error.message}`);
        process.exit();
    }
}
