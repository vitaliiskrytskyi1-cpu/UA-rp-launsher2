package ua.rp.launcher

/**
 * ГОЛОВНІ НАЛАШТУВАННЯ ЛАУНЧЕРА.
 * Усе, що потрібно змінити під свій сервер, — тут.
 */
object Config {
    /** Назва сервера (показується зверху). */
    const val SERVER_NAME = "UA RolePlay"

    /** IP або домен вашого open.mp сервера і порт. */
    const val SERVER_HOST = "147.185.221.218"
    const val SERVER_PORT = 11692

    /**
     * Адреса папки на хостингу, де лежать news.json і manifest.json
     * (наприклад, GitHub Pages або ваш VPS). Обов'язково https і зі слешем у кінці.
     */
    const val CDN_URL = "https://raw.githubusercontent.com/vitaliiskrytskyi1-cpu/UA-rp-launsher2/main/hosting/"

    /** Пакет ігрового клієнта SA:MP для Android, який запускає кнопка «Грати». */
    const val CLIENT_PACKAGE = "gta.ua.apk"

    /** Офіційна GTA San Andreas з Google Play — гравець купує її сам. */
    const val GTA_PACKAGE = "com.rockstargames.gtasa"

    /** Посилання на Discord / Telegram сервера (кнопки внизу). Порожньо — кнопку сховано. */
    const val DISCORD_URL = ""
    const val TELEGRAM_URL = ""

    /**
     * Версія цього лаунчера. Коли випускаєте новий APK — збільшіть її (і versionCode
     * в app/build.gradle.kts), а в manifest.json вкажіть "launcher_version" і "launcher_url".
     * Старі лаунчери тоді попросять оновитися.
     */
    const val LAUNCHER_VERSION = 1

    /** Як часто оновлювати онлайн, мс. */
    const val STATUS_REFRESH_MS = 15_000L
}
