# kotlinx.serialization: keep generated serializers of the content model
-keepattributes *Annotation*, InnerClasses
-keep,includedescriptorclasses class app.mossling.**$$serializer { *; }
-keepclassmembers class app.mossling.** { *** Companion; }
-keepclasseswithmembers class app.mossling.** { kotlinx.serialization.KSerializer serializer(...); }
