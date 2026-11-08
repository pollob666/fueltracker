# WorkManager & Room Database
# Prevents R8 from stripping or obfuscating WorkDatabase and its reflection-instantiated implementation
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.work.impl.**
-dontwarn androidx.work.**

-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keepclassmembers class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}

# AndroidX Startup
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer {
    <init>();
}

# Google Mobile Ads SDK & AdMob
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.common.**
-keep class com.google.ads.mediation.** { *; }

# Flutter Local Notifications & Gson
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Home Widget Provider
-keep class com.pollob666.fueltracker.RefuelGlanceWidgetProvider { *; }
-keep class es.antonborri.home_widget.** { *; }

