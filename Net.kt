package ua.rp.launcher

import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

data class NewsItem(val title: String, val date: String, val text: String)

data class RemoteFile(val path: String, val size: Long, val sha256: String)

data class Manifest(
    val version: Int,
    val launcherVersion: Int,
    val launcherUrl: String,
    val files: List<RemoteFile>
)

/** Мережа: новини, маніфест файлів і завантаження. Усе — блокуючі виклики для фонового потоку. */
object Net {

    private fun open(url: String): HttpURLConnection {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 8000
        c.readTimeout = 15000
        c.useCaches = false
        c.setRequestProperty("User-Agent", "UARPLauncher/1.0")
        return c
    }

    fun getText(url: String): String {
        val c = open(url)
        try {
            if (c.responseCode !in 200..299) throw Exception("HTTP ${c.responseCode}")
            return c.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } finally {
            c.disconnect()
        }
    }

    /**
     * news.json:
     * { "news": [ { "title": "...", "date": "06.11.2026", "text": "..." } ] }
     */
    fun loadNews(): List<NewsItem> {
        val json = JSONObject(getText(Config.CDN_URL + "news.json"))
        val arr = json.optJSONArray("news") ?: return emptyList()
        val out = ArrayList<NewsItem>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            out.add(NewsItem(o.optString("title"), o.optString("date"), o.optString("text")))
        }
        return out
    }

    /**
     * manifest.json (генерується скриптом make_manifest.py):
     * { "version": 1, "launcher_version": 1, "launcher_url": "",
     *   "files": [ { "path": "hud/logo.png", "size": 1234, "sha256": "..." } ] }
     */
    fun loadManifest(): Manifest {
        val json = JSONObject(getText(Config.CDN_URL + "manifest.json"))
        val arr = json.optJSONArray("files")
        val files = ArrayList<RemoteFile>()
        if (arr != null) {
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                val path = o.getString("path")
                // Захист: жодних шляхів, що виходять за межі папки гри
                if (path.startsWith("/") || path.contains("..") || path.contains("\\")) continue
                files.add(RemoteFile(path, o.optLong("size"), o.getString("sha256").lowercase()))
            }
        }
        return Manifest(
            json.optInt("version", 0),
            json.optInt("launcher_version", 0),
            json.optString("launcher_url", ""),
            files
        )
    }

    fun sha256(file: File): String {
        val md = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buf = ByteArray(64 * 1024)
            while (true) {
                val n = input.read(buf)
                if (n <= 0) break
                md.update(buf, 0, n)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    /** Завантажує файл у тимчасовий .part, перевіряє хеш і лише тоді замінює старий. */
    fun download(url: String, target: File, expectedSha: String, onBytes: (Long) -> Unit) {
        target.parentFile?.mkdirs()
        val part = File(target.path + ".part")
        val c = open(url)
        try {
            if (c.responseCode !in 200..299) throw Exception("HTTP ${c.responseCode}: $url")
            c.inputStream.use { input ->
                FileOutputStream(part).use { out ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n <= 0) break
                        out.write(buf, 0, n)
                        onBytes(n.toLong())
                    }
                }
            }
        } finally {
            c.disconnect()
        }
        if (sha256(part) != expectedSha) {
            part.delete()
            throw Exception("Файл пошкоджено під час завантаження: ${target.name}")
        }
        if (target.exists()) target.delete()
        if (!part.renameTo(target)) throw Exception("Не вдалося зберегти ${target.name}")
    }
}
