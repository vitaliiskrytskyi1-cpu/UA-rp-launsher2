package ua.rp.launcher

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.graphics.Typeface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.format.Formatter
import android.util.TypedValue
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : Activity() {

    private lateinit var statusDot: View
    private lateinit var statusText: TextView
    private lateinit var pingText: TextView
    private lateinit var onlineText: TextView
    private lateinit var onlineBar: ProgressBar
    private lateinit var nickInput: EditText
    private lateinit var updateText: TextView
    private lateinit var updateBar: ProgressBar
    private lateinit var playButton: Button
    private lateinit var newsList: LinearLayout

    private val main = Handler(Looper.getMainLooper())
    private val io: ExecutorService = Executors.newFixedThreadPool(3)
    private lateinit var updater: Updater

    /** Файли, які ще треба завантажити. null — маніфест ще не отримано. */
    private var pendingFiles: List<RemoteFile>? = null
    private var updating = false
    private var manifestFailed = false

    private val statusLoop = object : Runnable {
        override fun run() {
            refreshStatus()
            main.postDelayed(this, Config.STATUS_REFRESH_MS)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_main)
        updater = Updater(this)

        statusDot = findViewById(R.id.statusDot)
        statusText = findViewById(R.id.statusText)
        pingText = findViewById(R.id.pingText)
        onlineText = findViewById(R.id.onlineText)
        onlineBar = findViewById(R.id.onlineBar)
        nickInput = findViewById(R.id.nickInput)
        updateText = findViewById(R.id.updateText)
        updateBar = findViewById(R.id.updateBar)
        playButton = findViewById(R.id.playButton)
        newsList = findViewById(R.id.newsList)

        findViewById<TextView>(R.id.title).text = Config.SERVER_NAME
        nickInput.setText(prefs().getString(KEY_NICK, ""))

        setupSocial(R.id.discordButton, Config.DISCORD_URL)
        setupSocial(R.id.telegramButton, Config.TELEGRAM_URL)

        playButton.setOnClickListener { onPlayClicked() }

        loadNews()
        checkUpdates()
    }

    override fun onResume() {
        super.onResume()
        main.post(statusLoop)
    }

    override fun onPause() {
        super.onPause()
        main.removeCallbacks(statusLoop)
        saveNick()
    }

    override fun onDestroy() {
        super.onDestroy()
        io.shutdownNow()
    }

    // ---------------------------------------------------------------- статус сервера

    private fun refreshStatus() {
        io.execute {
            val info = SampQuery.query(Config.SERVER_HOST, Config.SERVER_PORT)
            main.post {
                if (isFinishing) return@post
                if (info == null) {
                    statusDot.setBackgroundResource(R.drawable.dot_offline)
                    statusText.setText(R.string.status_offline)
                    pingText.text = ""
                    onlineText.text = "— / —"
                    onlineBar.progress = 0
                } else {
                    statusDot.setBackgroundResource(R.drawable.dot_online)
                    statusText.setText(R.string.status_online)
                    pingText.text = "${info.pingMs} мс"
                    onlineText.text = "${info.players} / ${info.maxPlayers}"
                    onlineBar.progress =
                        if (info.maxPlayers > 0) info.players * 100 / info.maxPlayers else 0
                }
            }
        }
    }

    // ---------------------------------------------------------------- новини

    private fun loadNews() {
        showNewsMessage(getString(R.string.news_loading))
        io.execute {
            val result = try {
                Net.loadNews()
            } catch (e: Exception) {
                null
            }
            main.post {
                if (isFinishing) return@post
                when {
                    result == null -> showNewsMessage(getString(R.string.news_error))
                    result.isEmpty() -> showNewsMessage(getString(R.string.news_empty))
                    else -> showNews(result)
                }
            }
        }
    }

    private fun showNewsMessage(msg: String) {
        newsList.removeAllViews()
        newsList.addView(textView(msg, 14f, R.color.text_dim, false))
    }

    private fun showNews(items: List<NewsItem>) {
        newsList.removeAllViews()
        for (item in items) {
            val box = LinearLayout(this)
            box.orientation = LinearLayout.VERTICAL
            box.setBackgroundResource(R.drawable.bg_input)
            val p = dp(12)
            box.setPadding(p, p, p, p)
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
            lp.bottomMargin = dp(10)
            box.layoutParams = lp

            box.addView(textView(item.title, 16f, R.color.text, true))
            if (item.date.isNotBlank()) box.addView(textView(item.date, 12f, R.color.accent, false))
            val body = textView(item.text, 14f, R.color.text_dim, false)
            (body.layoutParams as? LinearLayout.LayoutParams)?.topMargin = dp(4)
            box.addView(body)
            newsList.addView(box)
        }
    }

    private fun textView(text: String, sizeSp: Float, colorRes: Int, bold: Boolean): TextView {
        val tv = TextView(this)
        tv.text = text
        tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        tv.setTextColor(getColor(colorRes))
        if (bold) tv.setTypeface(tv.typeface, Typeface.BOLD)
        tv.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        )
        return tv
    }

    // ---------------------------------------------------------------- оновлення файлів

    private fun checkUpdates() {
        updateText.setText(R.string.update_checking)
        io.execute {
            val manifest = try {
                Net.loadManifest()
            } catch (e: Exception) {
                null
            }
            val toUpdate = manifest?.let { updater.filesToUpdate(it) }
            main.post {
                if (isFinishing) return@post
                if (manifest == null) {
                    manifestFailed = true
                    pendingFiles = null
                    updateText.setText(R.string.update_offline)
                    refreshPlayButton()
                    return@post
                }
                manifestFailed = false
                if (manifest.launcherVersion > Config.LAUNCHER_VERSION) {
                    showLauncherUpdate(manifest.launcherUrl)
                }
                pendingFiles = toUpdate
                if (toUpdate.isNullOrEmpty()) {
                    updateText.setText(R.string.update_ok)
                } else {
                    val size = Formatter.formatShortFileSize(this, toUpdate.sumOf { it.size })
                    updateText.text = getString(R.string.update_needed, toUpdate.size, size)
                }
                refreshPlayButton()
            }
        }
    }

    private fun startUpdate(files: List<RemoteFile>) {
        updating = true
        refreshPlayButton()
        updateBar.visibility = View.VISIBLE
        updateBar.progress = 0
        io.execute {
            var error: String? = null
            try {
                var lastUi = 0L
                updater.update(files) { done, total, _ ->
                    val now = System.currentTimeMillis()
                    if (now - lastUi > 150 || done >= total) {
                        lastUi = now
                        main.post {
                            updateBar.progress = (done * 1000 / total).toInt()
                            updateText.text = getString(
                                R.string.update_progress,
                                Formatter.formatShortFileSize(this, done),
                                Formatter.formatShortFileSize(this, total)
                            )
                        }
                    }
                }
            } catch (e: Exception) {
                error = e.message ?: e.javaClass.simpleName
            }
            val err = error
            main.post {
                if (isFinishing) return@post
                updating = false
                updateBar.visibility = View.GONE
                if (err != null) {
                    updateText.text = getString(R.string.update_error, err)
                    refreshPlayButton()
                } else {
                    checkUpdates()
                }
            }
        }
    }

    private fun refreshPlayButton() {
        val needUpdate = !pendingFiles.isNullOrEmpty()
        playButton.setText(if (needUpdate) R.string.update else R.string.play)
        playButton.isEnabled = !updating
    }

    // ---------------------------------------------------------------- кнопка «Грати»

    private fun onPlayClicked() {
        val files = pendingFiles
        if (!files.isNullOrEmpty()) {
            startUpdate(files)
            return
        }
        if (manifestFailed && !updater.hasLocalFiles()) {
            // Ще жодного разу не завантажували файли, а сервер оновлень недоступний — пробуємо знову
            checkUpdates()
            return
        }

        val nick = nickInput.text.toString().trim()
        if (!NICK_REGEX.matches(nick) || nick.length > 20) {
            nickInput.error = getString(R.string.nick_error)
            nickInput.requestFocus()
            return
        }
        saveNick()
        hideKeyboard()

        if (!GameLauncher.isInstalled(this, Config.GTA_PACKAGE)) {
            AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert)
                .setTitle(R.string.gta_missing_title)
                .setMessage(R.string.gta_missing_text)
                .setPositiveButton(R.string.open_play) { _, _ ->
                    GameLauncher.openPlayStore(this, Config.GTA_PACKAGE)
                }
                .setNegativeButton(R.string.later, null)
                .show()
            return
        }

        if (!GameLauncher.launch(this, nick, updater.gameDir.absolutePath)) {
            AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert)
                .setTitle(R.string.client_missing_title)
                .setMessage(R.string.client_missing_text)
                .setPositiveButton(R.string.ok, null)
                .show()
        }
    }

    private fun showLauncherUpdate(url: String) {
        val b = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert)
            .setTitle(R.string.launcher_update_title)
            .setMessage(R.string.launcher_update_text)
            .setNegativeButton(R.string.later, null)
        if (url.startsWith("https://")) {
            b.setPositiveButton(R.string.download) { _, _ -> GameLauncher.openUrl(this, url) }
        }
        b.show()
    }

    // ---------------------------------------------------------------- дрібниці

    private fun setupSocial(id: Int, url: String) {
        val btn = findViewById<Button>(id)
        if (url.isBlank()) {
            btn.visibility = View.GONE
        } else {
            btn.setOnClickListener { GameLauncher.openUrl(this, url) }
        }
    }

    private fun prefs() = getSharedPreferences("launcher", Context.MODE_PRIVATE)

    private fun saveNick() {
        prefs().edit().putString(KEY_NICK, nickInput.text.toString().trim()).apply()
    }

    private fun hideKeyboard() {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.hideSoftInputFromWindow(nickInput.windowToken, 0)
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    companion object {
        private const val KEY_NICK = "nick"

        /** RP-формат: Ім'я_Прізвище латиницею, кожне з великої літери. */
        private val NICK_REGEX = Regex("^[A-Z][a-z]{1,15}_[A-Z][a-z]{1,15}$")
    }
}
