package ua.rp.launcher

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build

/** Запуск гри: перевірка GTA SA і клієнта, передача ніка та адреси сервера. */
object GameLauncher {

    fun isInstalled(context: Context, pkg: String): Boolean = try {
        if (Build.VERSION.SDK_INT >= 33) {
            context.packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(pkg, 0)
        }
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    fun openPlayStore(context: Context, pkg: String) {
        try {
            context.startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (e: ActivityNotFoundException) {
            openUrl(context, "https://play.google.com/store/apps/details?id=$pkg")
        }
    }

    fun openUrl(context: Context, url: String) {
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: ActivityNotFoundException) {
            // немає браузера — нічого не робимо
        }
    }

    /**
     * Запускає клієнт. Нік, IP, порт і шлях до файлів сервера передаються як extras.
     * Ваш клієнт має прочитати їх у своїй головній Activity:
     *   intent.getStringExtra("nick"), getStringExtra("host"), getIntExtra("port", 7777),
     *   getStringExtra("files_dir")
     * Повертає false, якщо клієнт не вдалося запустити.
     */
    fun launch(context: Context, nick: String, filesDir: String): Boolean {
        val intent = context.packageManager.getLaunchIntentForPackage(Config.CLIENT_PACKAGE) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.putExtra("nick", nick)
        intent.putExtra("host", Config.SERVER_HOST)
        intent.putExtra("port", Config.SERVER_PORT)
        intent.putExtra("files_dir", filesDir)
        return try {
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
