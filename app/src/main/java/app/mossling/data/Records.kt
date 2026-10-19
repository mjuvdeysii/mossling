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
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

/**
 * What the family has recorded. Three different things are never mixed:
 *  - kind "c": something observed (看到过)
 *  - kind "a": a play that was done (做过) — says nothing about a skill being reached
 *  - kind "v"/"k": a vaccine / a check-up that really happened (only ever ticked one by one)
 */
@Entity(tableName = "ticks")
data class Tick(@PrimaryKey val key: String, val month: Int, val kind: String, val label: String, val at: Long)

/** One journal entry. [end] is set for things with a duration (a feed, a sleep). */
@Entity(tableName = "logs")
data class LogEntry(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val type: String,
    val start: Long,
    val end: Long? = null,
    val amount: Int? = null,
    val side: String? = null,
    val detail: String? = null,
)

/** A timer that is running (at most one per type). Kept in the database so it survives the process. */
@Entity(tableName = "timers")
data class RunningTimer(
    @PrimaryKey val type: String,
    val start: Long,
    val side: String? = null,
    val pausedAt: Long? = null,
    val pausedTotal: Long = 0,
)

object TickKind { const val Observed = "c"; const val Did = "a"; const val Vaccine = "v"; const val Checkup = "k" }
object LogType { const val Nurse = "nurse"; const val Bottle = "bottle"; const val Sleep = "sleep"; const val Diaper = "diaper"; const val Solid = "solid"; const val Bath = "bath"; const val Note = "note" }

fun tickKey(month: Int, kind: String, id: String) = "$month:$kind:$id"

@Dao
interface RecordDao {
    @Query("SELECT * FROM ticks") fun ticks(): Flow<List<Tick>>
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun putTick(t: Tick)
    @Query("DELETE FROM ticks WHERE `key` = :key") suspend fun dropTick(key: String)
    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun putTickIfAbsent(t: Tick): Long
    @Query("SELECT COUNT(*) FROM logs WHERE type = :type AND start > :from AND start < :to") suspend fun sameMinute(type: String, from: Long, to: Long): Int

    @Query("SELECT * FROM logs WHERE start >= :from AND start < :to ORDER BY start DESC") fun logs(from: Long, to: Long): Flow<List<LogEntry>>
    @Query("SELECT * FROM logs ORDER BY start DESC LIMIT 1") fun latest(): Flow<LogEntry?>
    @Query("SELECT * FROM logs WHERE type IN (:types) ORDER BY start DESC LIMIT 1") suspend fun lastOf(types: List<String>): LogEntry?
    @Insert suspend fun putLog(e: LogEntry): Long
    @Update suspend fun updateLog(e: LogEntry)
    @Query("DELETE FROM logs WHERE id = :id") suspend fun dropLog(id: Long)

    @Query("SELECT * FROM timers") fun timers(): Flow<List<RunningTimer>>
    @Query("SELECT * FROM timers WHERE type = :type") suspend fun timer(type: String): RunningTimer?
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun putTimer(t: RunningTimer)
    @Query("DELETE FROM timers WHERE type = :type") suspend fun dropTimer(type: String): Int
}

@Database(entities = [Tick::class, LogEntry::class, RunningTimer::class], version = 1, exportSchema = true)
abstract class RecordsDb : RoomDatabase() {
    abstract fun dao(): RecordDao
    companion object {
        fun open(context: Context) = Room.databaseBuilder(context, RecordsDb::class.java, "records.db").build()
    }
}
