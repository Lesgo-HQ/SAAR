package com.lesgo.saar

import android.app.Application
import com.lesgo.saar.data.SaarDatabase
import com.lesgo.saar.data.SaarRepository
import com.lesgo.saar.flow.FlowMatcher
import com.lesgo.saar.flow.FlowSynthesizer
import com.lesgo.saar.flow.LocalSemanticReasoner

class SaarApplication : Application() {
    val repository by lazy { SaarRepository(SaarDatabase.get(this).saarDao()) }
    val reasoner by lazy { LocalSemanticReasoner() }
    val flowSynthesizer by lazy { FlowSynthesizer(reasoner) }
    val flowMatcher by lazy { FlowMatcher(repository, reasoner) }
}
