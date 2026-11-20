# ==============================================================================
# ProGuard / R8 Rules for Almurakib Egypt Stocks
# Optimizes DEX code and enables Obfuscation while keeping critical SDKs intact
# ==============================================================================

# ---------------- Flutter Framework & Plugins ----------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ---------------- Google Play Core (Deferred Components) ----------------
-dontwarn com.google.android.play.core.**

# ---------------- Application Specific ----------------
-keep class com.almurakib.egyptappstocks.** { *; }

# ---------------- AndroidX & Edge-to-Edge ----------------
-keep class androidx.activity.** { *; }
-dontwarn androidx.activity.**

# ---------------- Facebook SDK ----------------
-keep class com.facebook.** { *; }
-keepclassmembers class com.facebook.** { *; }
-keepclassmembers class com.facebook.login.** { *; }
-dontwarn com.facebook.**

# ---------------- Firebase & Google Play Services ----------------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ---------------- Desugaring & Reflection ----------------
-dontwarn java.lang.invoke.**
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable CREATORs
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep Serializable
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
