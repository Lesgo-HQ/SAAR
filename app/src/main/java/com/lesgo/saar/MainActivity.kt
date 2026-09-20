package com.lesgo.saar

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.google.android.material.color.MaterialColors
import com.google.android.material.card.MaterialCardView
import com.lesgo.saar.automation.AutomationStatus
import com.lesgo.saar.automation.SaarAccessibilityService
import com.lesgo.saar.domain.AutomationMode
import com.lesgo.saar.domain.MatchResult
import com.lesgo.saar.voice.VoiceCapture
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import java.util.Locale

class MainActivity : AppCompatActivity(), VoiceCapture.Callback {
    private lateinit var requestInput: EditText
    private lateinit var statusText: TextView
    private lateinit var flowList: LinearLayout
    private lateinit var micButton: Button
    private lateinit var voiceCapture: VoiceCapture
    private var speaker: TextToSpeech? = null

    private val audioPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) voiceCapture.start() else renderMessage("Microphone permission is needed for voice capture. You can still type a request.")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        speaker = TextToSpeech(this) { if (it == TextToSpeech.SUCCESS) speaker?.language = Locale.getDefault() }
        voiceCapture = VoiceCapture(this, this)
        setContentView(buildContent())
        lifecycleScope.launch { SaarAccessibilityService.status.collectLatest(::renderStatus) }
        refreshFlows()
    }

    override fun onResume() {
        super.onResume()
        renderMessage(if (automationEnabled()) "Automation ready" else "Enable accessibility automation before teaching or replaying")
        refreshFlows()
    }

    private fun buildContent(): View {
        val padding = dp(20)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding, padding, padding)
        }
        root.addView(TextView(this).apply {
            text = "SAAR\nSpeech-Aware Adaptive Automation & Replay"
            textSize = 24f
            setTextColor(MaterialColors.getColor(this, com.google.android.material.R.attr.colorOnSurface, Color.BLACK))
        })
        root.addView(TextView(this).apply {
            text = "Teach a task once by voice and touch. SAAR stores semantic UI roles, not tap coordinates."
            textSize = 14f
            setPadding(0, dp(8), 0, dp(16))
        })
        statusText = TextView(this).apply { textSize = 15f; setPadding(dp(16), dp(14), dp(16), dp(14)) }
        root.addView(MaterialCardView(this).apply { radius = dp(16).toFloat(); addView(statusText) }, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        requestInput = EditText(this).apply {
            hint = "Say or type: order garlic bread from Domino's"
            minLines = 2
            setPadding(dp(12), dp(16), dp(12), dp(8))
        }
        root.addView(requestInput, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        micButton = Button(this).apply { text = "Speak request"; setOnClickListener { listen() } }
        root.addView(micButton, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        root.addView(buttonRow("Teach this task", "Finish teaching") { first -> if (first) startTeaching() else finishTeaching() })
        root.addView(buttonRow("Run learned task", "Enable accessibility") { first -> if (first) runCommand() else openAccessibilitySettings() })
        root.addView(TextView(this).apply { text = "Learned flows"; textSize = 18f; setPadding(0, dp(20), 0, dp(8)) })
        flowList = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(flowList)
        return ScrollView(this).apply { addView(root) }
    }

    private fun buttonRow(firstText: String, secondText: String, action: (Boolean) -> Unit): View = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        val first = Button(this@MainActivity).apply { text = firstText; setOnClickListener { action(true) } }
        val second = Button(this@MainActivity).apply { text = secondText; setOnClickListener { action(false) } }
        addView(first, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        addView(second, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
    }

    private fun listen() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) voiceCapture.start()
        else audioPermission.launch(Manifest.permission.RECORD_AUDIO)
    }

    private fun startTeaching() {
        val service = requireService() ?: return
        service.beginTeaching(requestInput.text.toString())
    }

    private fun finishTeaching() {
        SaarAccessibilityService.active()?.finishTeaching() ?: renderMessage("Accessibility service is not connected")
    }

    private fun runCommand() {
        val service = requireService() ?: return
        val request = (application as SaarApplication).reasoner.parseRequest(requestInput.text.toString())
        if (request.rawText.isBlank()) return renderMessage("Tell me what you want to run")
        if (request.teachRequested) return service.beginTeaching(request.intentPhrase)
        lifecycleScope.launch {
            when (val match = (application as SaarApplication).flowMatcher.match(request, null)) {
                is MatchResult.Match -> service.replay(match.flow, match.slots)
                is MatchResult.Ambiguous -> renderMessage("I found more than one likely flow: ${match.candidates.joinToString { it.triggerIntent }}. Please be more specific.")
                is MatchResult.Unknown -> renderMessage(match.explanation)
            }
        }
    }

    private fun requireService(): SaarAccessibilityService? {
        val service = SaarAccessibilityService.active()
        if (service == null) openAccessibilitySettings()
        return service
    }

    private fun openAccessibilitySettings() = startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))

    private fun automationEnabled(): Boolean {
        val manager = getSystemService(Context.ACCESSIBILITY_SERVICE) as android.view.accessibility.AccessibilityManager
        return manager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK).any { it.resolveInfo.serviceInfo.packageName == packageName && it.resolveInfo.serviceInfo.name == "${packageName}.automation.SaarAccessibilityService" }
    }

    private fun renderStatus(status: AutomationStatus) {
        statusText.text = status.message
        val shouldSpeak = status.mode in setOf(AutomationMode.PAUSED_SENSITIVE, AutomationMode.NEEDS_CLARIFICATION)
        if (shouldSpeak) speaker?.speak(status.message, TextToSpeech.QUEUE_FLUSH, null, "saar-status")
    }

    private fun renderMessage(message: String) { if (::statusText.isInitialized) statusText.text = message }

    private fun refreshFlows() = lifecycleScope.launch {
        val flows = (application as SaarApplication).repository.flows()
        flowList.removeAllViews()
        if (flows.isEmpty()) flowList.addView(TextView(this@MainActivity).apply { text = "No flows yet. Enter a request, tap Teach, then demonstrate it in a target app." })
        flows.forEach { flow ->
            flowList.addView(MaterialCardView(this@MainActivity).apply {
                setContentPadding(dp(14), dp(12), dp(14), dp(12))
                addView(TextView(this@MainActivity).apply { text = "${flow.triggerIntent.replace('_', ' ')}  ·  ${flow.steps.size} steps\n${flow.appPackage}" })
            }, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) })
        }
    }

    override fun onTranscript(text: String) { requestInput.setText(text); requestInput.setSelection(text.length) }
    override fun onListeningChanged(listening: Boolean) { micButton.text = if (listening) "Listening…" else "Speak request" }
    override fun onVoiceError(message: String) = renderMessage(message)
    override fun onDestroy() { voiceCapture.destroy(); speaker?.shutdown(); super.onDestroy() }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
}
