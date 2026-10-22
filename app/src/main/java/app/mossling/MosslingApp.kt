package app.mossling

import android.app.Application
import android.content.Context
import app.mossling.data.ContentRepository
import app.mossling.data.RecordsDb
import app.mossling.data.SettingsRepository
import app.mossling.journal.Timers
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class MosslingApp : Application() {
    lateinit var graph: Graph
        private set

    override fun onCreate() {
        super.onCreate()
        CrashLog.install(this)
        graph = Graph(this)
        // read the content and bring back running timers off the main thread, before the first screen needs them
        graph.scope.launch {
            graph.content.get(); graph.timers.restore(graph.db.dao().timers().first())
            graph.settings.settleJournal { graph.db.dao().allLogs().isNotEmpty() || graph.db.dao().timers().first().isNotEmpty() }
        }
    }
}

class Graph(context: Context) {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    val content = ContentRepository(context)
    val settings = SettingsRepository(context)
    val db: RecordsDb by lazy { RecordsDb.open(context) }
    val timers: Timers by lazy { Timers(context, db.dao()) }
    val exporter: app.mossling.data.Exporter by lazy { app.mossling.data.Exporter(context, db.dao(), settings) }
    val growth: app.mossling.domain.Growth by lazy { app.mossling.domain.Growth.parse(context.assets.open("who_growth.json").bufferedReader().readText()) }
    val updater: app.mossling.domain.Updater by lazy { app.mossling.domain.Updater(context, scope) }
    val importer: app.mossling.data.Importer by lazy { app.mossling.data.Importer(db.dao(), settings) }
}
