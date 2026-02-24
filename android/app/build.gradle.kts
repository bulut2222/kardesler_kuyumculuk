plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    // Firebase Console'daki Paket Adı ile birebir eşlendi
    namespace = "com.yourname.kardeslerkuyumcusu" 

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Firebase ve JSON dosyandaki paket adı
        applicationId = "com.yourname.kardeslerkuyumcusu" 
        
        // Firebase için en güvenli minimum SDK versiyonu
        minSdk = flutter.minSdkVersion 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Büyük kütüphaneler için MultiDex desteği
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Firebase plugin tetikleyicisi
apply(plugin = "com.google.gms.google-services")
