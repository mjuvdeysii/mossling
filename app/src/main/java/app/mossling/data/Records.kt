package app.mossling.data

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.Serializable

/**
 * A checkmark the parent made: an activity done in a month, a milestone noticed, a vaccine or checkup completed.
 * [key] is `"$month:$kind:$item"`, stable across launches.
 */
@Entity(tableName = "ticks")
@Serializable
data class Tick(
    @PrimaryKey val key: String,
    val month: Int,
    val kind: String,
    val label: String,
    val at: Long,
)

object TickKind {
    const val Did = "a"
    const val Observed = "o"
    const val Vaccine = "v"
    const val Checkup = "c"
}

fun tickKey(month: Int, kind: String, item: String) = "$month:$kind:$item"

/**
 * A single care log entry. Optional; lives on device; exported as JSON or CSV.
 */
@Entity(tableName = "logs")
@Serializable
data class LogEntry(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val type: String,
    val start: Long,
    val end: Long? = null,
    val amount: Int? = null,
    val side: String? = null,
    val detail: String? = null,
)

object LogType {
    const val Nurse = "nurse"
    const val Bottle = "bottle"
    const val Sleep = "sleep"
    const val Diaper = "diaper"
    const val Solid = "solid"
    const val Bath = "bath"
    const val Temp = "temp"
    const val Med = "med"
    const val Note = "note"
    const val Play = "play"
}

/**
 * A timer that is running right now (at most one per [type]: "nurse" or "sleep").
 * Stored in Room so it survives process death.
 * [carried] and [carriedPause] store the accumulated time on the other nursing side when switching sides.
 */
@Entity(tableName = "timers")
@Serializable
data class RunningTimer(
    @PrimaryKey val type: String,
    val start: Long,
    val side: String? = null,
    val pausedAt: Long? = null,
    val pausedTotal: Long = 0,
    val carried: Long = 0,
    val carriedPause: Long = 0,
)

/** A growth measurement: weight in grams, length in millimetres, head circumference in millimetres. */
@Entity(tableName = "measures")
@Serializable
data class Measure(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val at: Long,
    val weightG: Int? = null,
    val lengthMm: Int? = null,
    val headMm: Int? = null,
)

/**
 * A "First" milestone ("第一次", `ios/Mossling/Data/JournalStore.swift`):
 * e.g. first smile, first roll, first tooth, first steps, or a custom memory.
 */
@Entity(tableName = "firsts")
@Serializable
data class First(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val at: Long,
    val key: String = "custom",
    val title: String,
    val note: String? = null,
)

data class FirstPreset(val key: String, val title: String, val hint: String)

val FirstPresets = listOf(
    FirstPreset("smile", "第一次对着人笑", "醒着时看着大人的脸笑出来"),
    FirstPreset("roll", "第一次翻身", "自己从仰卧翻到趴着，或从趴着翻回来"),
    FirstPreset("laugh", "第一次笑出声", "咯咯地笑出声音"),
    FirstPreset("reach", "第一次伸手抓物", "看见玩具主动伸手去拿"),
    FirstPreset("solid", "第一口辅食", "尝试人生第一勺米粉或食物泥"),
    FirstPreset("tooth", "第一颗乳牙", "牙龈冒出小白尖"),
    FirstPreset("sit", "第一次独坐", "不用扶也能稳稳坐一会儿"),
    FirstPreset("crawl", "第一次爬行", "手脚配合往前爬"),
    FirstPreset("stand", "第一次扶站", "扶着家具自己站起来"),
    FirstPreset("word", "第一次有意识叫人", "看着爸爸或妈妈清楚地叫出来"),
    FirstPreset("walk", "第一次独立迈步", "松开手自己走出几步"),
    FirstPreset("spoon", "第一次自己拿勺吃", "自己把勺子送进嘴里"),
)

@Dao
interface RecordDao {
    @Query("SELECT * FROM ticks")
    fun ticks(): Flow<List<Tick>>

    @Query("SELECT * FROM ticks")
    suspend fun allTicks(): List<Tick>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun putTick(t: Tick)

    @Query("DELETE FROM ticks WHERE `key` = :key")
    suspend fun dropTick(key: String)

    @Query("SELECT * FROM logs WHERE start >= :from AND start < :to ORDER BY start DESC")
    fun logsBetween(from: Long, to: Long): Flow<List<LogEntry>>

    @Query("SELECT * FROM logs ORDER BY start DESC LIMIT 1")
    fun latestLog(): Flow<LogEntry?>

    @Query("SELECT * FROM logs WHERE type IN (:types) ORDER BY COALESCE(`end`, start) DESC LIMIT 1")
    fun latestOf(types: List<String>): Flow<LogEntry?>

    @Query("SELECT * FROM logs WHERE type IN (:types) ORDER BY COALESCE(`end`, start) DESC LIMIT 1")
    suspend fun lastOf(types: List<String>): LogEntry?

    @Query("SELECT * FROM logs ORDER BY start DESC")
    fun logsFlow(): Flow<List<LogEntry>>

    @Query("SELECT * FROM logs ORDER BY start ASC")
    suspend fun allLogs(): List<LogEntry>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun putLog(e: LogEntry): Long

    @Query("DELETE FROM logs WHERE id = :id")
    suspend fun dropLog(id: Long)

    @Query("SELECT * FROM timers")
    fun timers(): Flow<List<RunningTimer>>

    @Query("SELECT * FROM timers WHERE type = :type")
    suspend fun timer(type: String): RunningTimer?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun putTimer(t: RunningTimer)

    @Query("DELETE FROM timers WHERE type = :type")
    suspend fun dropTimer(type: String): Int

    @Query("SELECT * FROM measures ORDER BY at ASC")
    fun measures(): Flow<List<Measure>>

    @Query("SELECT * FROM measures ORDER BY at ASC")
    suspend fun allMeasures(): List<Measure>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun putMeasure(m: Measure): Long

    @Query("DELETE FROM measures WHERE id = :id")
    suspend fun dropMeasure(id: Long)

    @Query("SELECT * FROM firsts ORDER BY at DESC")
    fun firsts(): Flow<List<First>>

    @Query("SELECT * FROM firsts ORDER BY at ASC")
    suspend fun allFirsts(): List<First>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun putFirst(f: First): Long

    @Query("DELETE FROM firsts WHERE id = :id")
    suspend fun dropFirst(id: Long)

    @Query("DELETE FROM ticks")
    suspend fun clearTicks()

    @Query("DELETE FROM logs")
    suspend fun clearLogs()

    @Query("DELETE FROM timers")
    suspend fun clearTimers()

    @Query("DELETE FROM measures")
    suspend fun clearMeasures()

    @Query("DELETE FROM firsts")
    suspend fun clearFirsts()
}

val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("CREATE TABLE IF NOT EXISTS `measures` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `at` INTEGER NOT NULL, `weightG` INTEGER, `lengthMm` INTEGER, `headMm` INTEGER)")
        db.execSQL("CREATE TABLE IF NOT EXISTS `firsts` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `at` INTEGER NOT NULL, `key` TEXT NOT NULL, `title` TEXT NOT NULL, `note` TEXT)")
        runCatching { db.execSQL("ALTER TABLE `timers` ADD COLUMN `carried` INTEGER NOT NULL DEFAULT 0") }
        runCatching { db.execSQL("ALTER TABLE `timers` ADD COLUMN `carriedPause` INTEGER NOT NULL DEFAULT 0") }
    }
}

@Database(
    entities = [Tick::class, LogEntry::class, RunningTimer::class, Measure::class, First::class],
    version = 2,
    exportSchema = false,
)
abstract class RecordsDb : RoomDatabase() {
    abstract fun dao(): RecordDao

    companion object {
        fun open(context: Context): RecordsDb =
            Room.databaseBuilder(context, RecordsDb::class.java, "mossling.db")
                .addMigrations(MIGRATION_1_2)
                .addCallback(object : Callback() {
                    override fun onOpen(db: SupportSQLiteDatabase) {
                        super.onOpen(db)
                        db.execSQL("CREATE TABLE IF NOT EXISTS `firsts` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `at` INTEGER NOT NULL, `key` TEXT NOT NULL, `title` TEXT NOT NULL, `note` TEXT)")
                        runCatching { db.execSQL("ALTER TABLE `timers` ADD COLUMN `carried` INTEGER NOT NULL DEFAULT 0") }
                        runCatching { db.execSQL("ALTER TABLE `timers` ADD COLUMN `carriedPause` INTEGER NOT NULL DEFAULT 0") }
                    }
                })
                .build()
    }
}
