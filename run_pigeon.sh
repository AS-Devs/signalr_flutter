# Run this file to regenerate pigeon files
flutter pub run pigeon \
  --input pigeons/signalr_api.dart \
  --dart_out lib/signalr_api.dart \
  --objc_header_out ios/Classes/SignalrApi.h \
  --objc_source_out ios/Classes/SignalrApi.m \
  --objc_prefix FLT \
  --java_out android/src/main/java/dev/asdevs/signalr_flutter/SignalrApi.java \
  --java_package "dev.asdevs.signalr_flutter"