package app.varagh.varagh

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.varagh/open_with")
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "initialFile") {
                copySent(intent) { result.success(it) }
            } else {
                result.notImplemented()
            }
        }
    }

    // "Open with" while the app is already running.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        copySent(intent) { path -> if (path != null) channel?.invokeMethod("openFile", path) }
    }

    /**
     * Copies the file [intent] asks to view into the cache and hands its path
     * to [done] (null if there is none). The app can't read the original by
     * path, and its permission to read it ends with this activity.
     */
    private fun copySent(intent: Intent?, done: (String?) -> Unit) {
        val uri = intent?.data
        if (intent == null || uri == null || intent.action != Intent.ACTION_VIEW ||
            intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0 ||
            intent.getBooleanExtra(HANDLED, false)
        ) {
            done(null)
            return
        }
        // Each file is opened once, not again when the activity is rebuilt.
        intent.putExtra(HANDLED, true)
        val type = intent.type
        thread {
            val path = try {
                val target = File(File(cacheDir, "open_with").apply { mkdirs() }, nameOf(uri, type))
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { input.copyTo(it) }
                    target.path
                }
            } catch (e: Exception) {
                null
            }
            runOnUiThread { done(path) }
        }
    }

    /** The file's name, with an extension the importer can tell its type by. */
    private fun nameOf(uri: Uri, type: String?): String {
        var name: String? = null
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    ?.use { if (it.moveToFirst()) name = it.getString(0) }
            } catch (e: Exception) {
            }
        }
        val base = File(name ?: uri.lastPathSegment ?: "book").name
        val extension = when (type ?: contentResolver.getType(uri)) {
            "application/pdf" -> "pdf"
            "application/epub+zip" -> "epub"
            "text/markdown" -> "md"
            "text/html" -> "html"
            "text/plain" -> "txt"
            else -> null
        }
        val known = setOf("pdf", "epub", "md", "markdown", "txt", "html", "htm")
        return if (extension == null || base.substringAfterLast('.', "").lowercase() in known) base
        else "$base.$extension"
    }

    private companion object {
        const val HANDLED = "app.varagh.handled"
    }
}
