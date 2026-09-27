package bd.com.easybuy.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // The channel the server names for order, payment and chat updates.
        // Creating it again is a no-op, so this runs on every start.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("updates", "Order and message updates", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Order status, payments and replies from EasyBuy"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
