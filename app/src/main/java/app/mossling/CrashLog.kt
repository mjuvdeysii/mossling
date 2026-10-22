package app.mossling

import android.content.Context
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter

/**
 * If the app ever stops unexpectedly, the reason is written to a small file on this phone — nothing is sent anywhere.
 * On the next start, 「关于小苔花」 offers to share it, so the problem can be reported and fixed.
 */
object CrashLog {
    private fun file(ctx: Context) = File(ctx.filesDir, "last-crash.txt")

    fun install(ctx: Context) {
        val app = ctx.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { t, e ->
            runCatching {
                val sw = StringWriter(); e.printStackTrace(PrintWriter(sw))
                val v = runCatching { app.packageManager.getPackageInfo(app.packageName, 0).versionName }.getOrNull()
                file(app).writeText("Mossling $v · Android ${android.os.Build.VERSION.RELEASE} (API ${android.os.Build.VERSION.SDK_INT}) · ${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}\n" +
                    "thread ${t.name} · ${java.time.Instant.now()}\n\n" + sw.toString().take(12_000))
            }
            previous?.uncaughtException(t, e)
        }
    }

    fun read(ctx: Context): String? = file(ctx).takeIf { it.exists() }?.readText()
    fun clear(ctx: Context) { file(ctx).delete() }
}
