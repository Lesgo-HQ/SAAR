package com.lesgo.saar.data

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
import com.lesgo.saar.domain.FlowDefinition
import com.lesgo.saar.domain.FlowStep
import com.lesgo.saar.domain.SlotDefinition
import org.json.JSONArray
import org.json.JSONObject

@Entity(tableName = "flows")
data class FlowEntity(
    @PrimaryKey val id: String,
    val appPackage: String,
    val triggerIntent: String,
    val examplesJson: String,
    val slotsJson: String,
    val stepsJson: String,
    val createdAt: Long
)

@Entity(tableName = "session_logs")
data class SessionLogEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val flowId: String?,
    val status: String,
    val detail: String,
    val createdAt: Long = System.currentTimeMillis()
)

@Dao
interface SaarDao {
    @Query("SELECT * FROM flows ORDER BY createdAt DESC") suspend fun flows(): List<FlowEntity>
    @Query("SELECT * FROM flows WHERE id = :id") suspend fun flow(id: String): FlowEntity?
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun saveFlow(flow: FlowEntity)
    @Insert suspend fun log(entry: SessionLogEntity)
    @Query("SELECT * FROM session_logs ORDER BY createdAt DESC LIMIT :limit") suspend fun logs(limit: Int): List<SessionLogEntity>
}

@Database(entities = [FlowEntity::class, SessionLogEntity::class], version = 1, exportSchema = true)
abstract class SaarDatabase : RoomDatabase() {
    abstract fun saarDao(): SaarDao

    companion object {
        @Volatile private var instance: SaarDatabase? = null
        fun get(context: Context): SaarDatabase = instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(context.applicationContext, SaarDatabase::class.java, "saar.db")
                .fallbackToDestructiveMigration()
                .build()
                .also { instance = it }
        }
    }
}

fun FlowDefinition.toEntity() = FlowEntity(
    id, appPackage, triggerIntent,
    JSONArray(examples).toString(),
    JSONArray().apply { slots.forEach { put(JSONObject().apply { put("name", it.name); put("type", it.type); put("default", it.defaultValue); put("required", it.required) }) } }.toString(),
    JSONArray().apply { steps.forEach { put(JSONObject().apply { put("id", it.id); put("action", it.action.name); put("role", it.targetRole.name); put("slot", it.valueSlot); put("expected", JSONArray(it.expectedRoles.map { role -> role.name })) }) } }.toString(),
    createdAt
)

fun FlowEntity.toDomain() = FlowDefinition(
    id, appPackage, triggerIntent,
    JSONArray(examplesJson).strings(),
    JSONArray(slotsJson).objects().map { SlotDefinition(it.getString("name"), it.getString("type"), it.optString("default").ifBlank { null }, it.optBoolean("required")) },
    JSONArray(stepsJson).objects().map { item ->
        FlowStep(item.getInt("id"), com.lesgo.saar.domain.ActionKind.valueOf(item.getString("action")), com.lesgo.saar.domain.ElementRole.valueOf(item.getString("role")), item.optString("slot").ifBlank { null }, item.optJSONArray("expected")?.strings()?.map { com.lesgo.saar.domain.ElementRole.valueOf(it) }?.toSet() ?: emptySet())
    }, createdAt
)

private fun JSONArray.strings() = (0 until length()).map { getString(it) }
private fun JSONArray.objects() = (0 until length()).map { getJSONObject(it) }
