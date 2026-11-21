import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp],
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const MyCamApp());
}

class MyCamApp extends StatelessWidget {
  const MyCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MY Cam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const CameraScreen(),
    );
  }
}
