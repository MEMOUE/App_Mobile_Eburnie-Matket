plugins {
    id("com.android.application")
    id("kotlin-android")
    // Le plugin Flutter doit être appliqué après Android et Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // AJOUT : Indispensable pour lire le fichier google-services.json
    id("com.google.gms.google-services")
}

android {
    // Changement : On utilise l'ID sans underscores pour correspondre à votre client Google
    namespace = "com.eburniemarket.appMobileEburnieMarket"
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
        // IMPORTANT : Cet ID doit être EXACTEMENT celui de votre console Google Cloud (ID Android)
        applicationId = "com.eburniemarket.appMobileEburnieMarket"
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Utilise la clé de debug pour permettre le test de la version release
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Les dépendances sont gérées par Flutter, mais vous pouvez en ajouter ici si nécessaire
}