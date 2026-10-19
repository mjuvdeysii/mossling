package app.mossling

import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import app.mossling.data.MIGRATION_1_2
import app.mossling.data.Measure
import app.mossling.data.RecordsDb
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

/** A version-1 database as the first releases wrote it must open in the current version with every record intact. */
@RunWith(AndroidJUnit4::class)
class MigrationTest {
    @Test fun v1ToCurrentKeepsEverything(): Unit = runBlocking {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        val name = "migration-test.db"
        ctx.deleteDatabase(name)
        SQLiteDatabase.openOrCreateDatabase(ctx.getDatabasePath(name), null).use { db ->
            db.execSQL("CREATE TABLE `ticks` (`key` TEXT NOT NULL, `month` INTEGER NOT NULL, `kind` TEXT NOT NULL, `label` TEXT NOT NULL, `at` INTEGER NOT NULL, PRIMARY KEY(`key`))")
            db.execSQL("CREATE TABLE `logs` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `type` TEXT NOT NULL, `start` INTEGER NOT NULL, `end` INTEGER, `amount` INTEGER, `side` TEXT, `detail` TEXT)")
            db.execSQL("CREATE TABLE `timers` (`type` TEXT NOT NULL, `start` INTEGER NOT NULL, `side` TEXT, `pausedAt` INTEGER, `pausedTotal` INTEGER NOT NULL, PRIMARY KEY(`type`))")
            db.execSQL("INSERT INTO ticks VALUES ('6:a:A11', 6, 'a', '双手物品传递机会', 1)")
            db.execSQL("INSERT INTO logs (type, start, amount) VALUES ('bottle', 1000, 120)")
            db.execSQL("INSERT INTO timers (type, start, pausedTotal) VALUES ('sleep', 2000, 0)")
            db.version = 1
        }
        val room = Room.databaseBuilder(ctx, RecordsDb::class.java, name).addMigrations(MIGRATION_1_2).build()
        val dao = room.dao()
        assertEquals(1, dao.allTicks().size)
        assertEquals(120, dao.allLogs().single().amount)
        assertEquals("sleep", dao.timer("sleep")?.type)
        dao.putMeasure(Measure(at = 3000, weightG = 7200))
        assertEquals(7200, dao.allMeasures().single().weightG)
        room.close(); ctx.deleteDatabase(name); Unit
    }
}
