# Keep Tesseract4Android JNI entry points. Book PDF recognition remains
# available for other app features even though dialogue preview uses pixels.
-keep class com.googlecode.tesseract.android.** { *; }

# Preserve Java/Kotlin classes whose functions are looked up from native code.
-keepclasseswithmembernames class * {
    native <methods>;
}
