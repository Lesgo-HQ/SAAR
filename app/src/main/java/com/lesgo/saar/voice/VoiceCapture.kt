package com.lesgo.saar.voice

import android.content.Context
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

class VoiceCapture(context: Context, private val callback: Callback) : RecognitionListener {
    interface Callback {
        fun onTranscript(text: String)
        fun onListeningChanged(listening: Boolean)
        fun onVoiceError(message: String)
    }

    private val recognizer = SpeechRecognizer.createSpeechRecognizer(context).also { it.setRecognitionListener(this) }

    fun start() {
        callback.onListeningChanged(true)
        recognizer.startListening(RecognizerIntent().apply {
            action = RecognizerIntent.ACTION_RECOGNIZE_SPEECH
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        })
    }

    fun destroy() = recognizer.destroy()
    override fun onReadyForSpeech(params: Bundle?) = Unit
    override fun onBeginningOfSpeech() = Unit
    override fun onRmsChanged(rmsdB: Float) = Unit
    override fun onBufferReceived(buffer: ByteArray?) = Unit
    override fun onEndOfSpeech() = Unit
    override fun onPartialResults(partialResults: Bundle?) = Unit
    override fun onEvent(eventType: Int, params: Bundle?) = Unit
    override fun onResults(results: Bundle?) {
        callback.onListeningChanged(false)
        results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.let(callback::onTranscript)
            ?: callback.onVoiceError("I couldn't understand that. Try again or type your request.")
    }
    override fun onError(error: Int) {
        callback.onListeningChanged(false)
        callback.onVoiceError("Voice recognition is unavailable ($error). You can type the request instead.")
    }
}
