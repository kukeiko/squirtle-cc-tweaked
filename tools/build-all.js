import { readFile, readdir, writeFile } from "fs/promises"
import luamin from "luamin"
import { join } from "path"

for (const directory of await readdir("dist")) {
    for (const app of await readdir(join("dist", directory))) {
        const contents = (await readFile(join("dist", directory, app))).toString()
        const minified = luamin.minify(contents)
        await writeFile(join("dist", directory, app), minified)
    }
}
