## Flutter / Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

## Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

## Razorpay
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
    public void onPayment*(...);
}

## YouTube Player
-keep class com.google.android.youtube.** { *; }
-dontwarn com.google.android.youtube.**

## Cloudinary
-keep class com.cloudinary.** { *; }
-dontwarn com.cloudinary.**

## Image Picker / file_picker
-keep class androidx.lifecycle.** { *; }

## WorkManager (background notifications)
-keep class androidx.work.** { *; }

## General OkHttp / Retrofit
-dontwarn okhttp3.**
-dontwarn okio.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

## Keep model classes from obfuscation (Dart classes don't need this, but keeps things safe)
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
