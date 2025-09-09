# Flutter-specific rules.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.embedding.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Add any project-specific rules here.
# If you use packages that require specific ProGuard rules, add them here.
# For example, for a package like `some_package`:
# -keep class com.somepackage.** { *; }
# -dontwarn com.somepackage.**
