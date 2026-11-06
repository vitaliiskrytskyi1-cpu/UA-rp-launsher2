package ua.rp.launcher

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.net.URLEncoder

/**
 * Перевіряє і докачує ВАШІ файли сервера (HUD, скіни, звуки, текстури) за manifest.json.
 * Файли самої GTA San Andreas лаунчер не завантажує — гравець ставить гру з Google Play.
 */
class Updater(private val context: Context) {

    /** Папка, куди кладуться файли сервера. Ігровий клієнт має читати їх звідси. */
    val gameDir: File
        get() = File(context.getExternalFilesDir(null) ?: context.filesDir, "game")

    private val indexFile: File
        get() = File(gameDir, ".index.json")

    private fun readIndex(): JSONObject = try {
        if (indexFile.exists()) JSONObject(indexFile.readText()) else JSONObject()
    } catch (e: Exception) {
        JSONObject()
    }

    /** Які файли треба завантажити (нових немає, або змінились). */
    fun filesToUpdate(manifest: Manifest): List<RemoteFile> {
        val index = readIndex()
        return manifest.files.filter { rf ->
            val local = File(gameDir, rf.path)
            !(local.exists() && local.length() == rf.size && index.optString(rf.path) == rf.sha256)
        }
    }

    /**
     * Завантажує список файлів. progress(завантажено_байт, всього_байт, поточний_файл).
     * Блокуючий виклик — тільки з фонового потоку.
     */
    fun update(files: List<RemoteFile>, progress: (Long, Long, String) -> Unit) {
        val total = files.sumOf { it.size }.coerceAtLeast(1)
        var done = 0L
        val index = readIndex()
        for (rf in files) {
            val url = Config.CDN_URL + "files/" + encodePath(rf.path)
            progress(done, total, rf.path)
            Net.download(url, File(gameDir, rf.path), rf.sha256) { n ->
                done += n
                progress(done, total, rf.path)
            }
            index.put(rf.path, rf.sha256)
            gameDir.mkdirs()
            indexFile.writeText(index.toString())
        }
        progress(total, total, "")
    }

    /** Чи все вже завантажено (для кнопки «Грати» без інтернету). */
    fun hasLocalFiles(): Boolean = indexFile.exists()

    private fun encodePath(path: String): String =
        path.split("/").joinToString("/") { URLEncoder.encode(it, "UTF-8").replace("+", "%20") }
}
