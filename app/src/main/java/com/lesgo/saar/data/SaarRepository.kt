package com.lesgo.saar.data

import com.lesgo.saar.domain.FlowDefinition
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class SaarRepository(private val dao: SaarDao) {
    suspend fun save(flow: FlowDefinition) = withContext(Dispatchers.IO) { dao.saveFlow(flow.toEntity()) }
    suspend fun flows(): List<FlowDefinition> = withContext(Dispatchers.IO) { dao.flows().map { it.toDomain() } }
    suspend fun log(flowId: String?, status: String, detail: String) = withContext(Dispatchers.IO) { dao.log(SessionLogEntity(flowId = flowId, status = status, detail = detail)) }
    suspend fun recentLogs() = withContext(Dispatchers.IO) { dao.logs(30) }
}
