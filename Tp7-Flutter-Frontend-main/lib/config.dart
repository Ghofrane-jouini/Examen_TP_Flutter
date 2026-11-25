import 'package:flutter/foundation.dart';

String get baseUrl {
  if (kIsWeb) {
    return "http://localhost:9090";
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    return "http://10.0.2.2:9090";
  } else {
    return "http://localhost:9090";
  }
}

const bool useMock = false;

// Configuration MySQL
const String dbHost = "127.0.0.1";
const int dbPort = 3306;
const String dbUser = "root";
const String dbPass = "";
const String dbName = "scolarite_abs";