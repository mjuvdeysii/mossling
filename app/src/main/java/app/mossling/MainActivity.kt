package app.mossling

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import kotlinx.coroutines.flow.MutableStateFlow

class MainActivity : FragmentActivity() {
    private val vm: AppViewModel by viewModels()
    /** where a notification asked to go ("journal"), consumed by the UI */
    val open = MutableStateFlow<String?>(null)
    private val askNotify = registerForActivityResult(ActivityResultContracts.RequestPermission()) { }
    /** true while the app lock (when turned on) waits for the person to confirm it is them */
    val locked = MutableStateFlow(false)
    private var away = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen().setKeepOnScreenCondition { !vm.ui.value.ready }
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        open.value = intent?.getStringExtra("open")
        setContent { MosslingRoot(vm, open, askNotifications = ::askNotifications, locked = locked, unlock = ::unlock) }
    }

    override fun onStart() {
        super.onStart()
        // locks on a cold start and after half a minute away; a quick switch to another app does not ask again
        if (vm.lockOn() && (away == 0L || System.currentTimeMillis() - away > 30_000)) { locked.value = true; unlock() }
    }

    override fun onStop() { super.onStop(); away = System.currentTimeMillis() }

    fun unlock() {
        val allowed = if (Build.VERSION.SDK_INT >= 30) BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL
            else BiometricManager.Authenticators.BIOMETRIC_WEAK
        if (BiometricManager.from(this).canAuthenticate(allowed) != BiometricManager.BIOMETRIC_SUCCESS) { locked.value = false; return }
        val info = BiometricPrompt.PromptInfo.Builder().setTitle("打开芽芽月历").setSubtitle("确认是你本人").setAllowedAuthenticators(allowed)
            .apply { if (Build.VERSION.SDK_INT < 30) setNegativeButtonText("取消") }.build()
        BiometricPrompt(this, ContextCompat.getMainExecutor(this), object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) { locked.value = false }
        }).authenticate(info)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra("open")?.let { open.value = it }
    }

    /** asked only when a timer is started for the first time: that is when a notification is useful */
    private fun askNotifications() {
        // never let the question itself stop a feed or a sleep from being recorded
        if (Build.VERSION.SDK_INT >= 33) runCatching { askNotify.launch(Manifest.permission.POST_NOTIFICATIONS) }
    }
}
