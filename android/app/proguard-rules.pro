# Flutter plugins are registered through generated embedding code. Keep model
# metadata used by platform channels while allowing R8 to optimize application code.
-keepattributes RuntimeVisibleAnnotations,AnnotationDefault
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
