package app.mossling

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import kotlinx.coroutines.flow.MutableStateFlow

class MainActivity : ComponentActivity() {
    private val vm: AppViewModel by viewModels()
    /** where a notification asked to go ("journal"), consumed by the UI */
    val open = MutableStateFlow<String?>(null)
    private val askNotify = registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen().setKeepOnScreenCondition { !vm.ui.value.ready }
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        open.value = intent?.getStringExtra("open")
        setContent { MosslingRoot(vm, open, askNotifications = ::askNotifications) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra("open")?.let { open.value = it }
    }

    /** asked only when a timer is started for the first time: that is when a notification is useful */
    private fun askNotifications() {
        if (Build.VERSION.SDK_INT >= 33) askNotify.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
}
