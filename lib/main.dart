import 'package:cactus/cactus.dart';

import 'package:flutter/material.dart';
import 'pages/basic_completion.dart';
import 'pages/chat.dart';
import 'pages/embedding.dart';
import 'pages/fetch_models.dart';
import 'pages/function_calling.dart';
import 'pages/hybrid_completion.dart';
import 'pages/rag.dart';
import 'pages/streaming_completion.dart';
// import 'pages/stt.dart';
import 'pages/vision.dart';
import 'pages/nexus_home.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cactus Examples',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.black,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 1,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black),
          ),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    CactusTelemetry.setTelemetryToken('a83c7f7a-43ad-4823-b012-cbeb587ae788');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cactus Examples'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        children: [
          // Big CTA for Nexus Project
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A0A0A), Color(0xFF2D2D2D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NexusHomePage()),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8CFF9E),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'HACKATHON PROJECT',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'NEXUS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Shared Knowledge Base',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.hub_outlined,
                            color: Color(0xFF8CFF9E),
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Standard Examples',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            title: const Text('Basic Completion'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const BasicCompletionPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Streaming Completion'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const StreamingCompletionPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Function Calling'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FunctionCallingPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Hybrid Completion'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const HybridCompletionPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Fetch Models'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FetchModelsPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Embedding'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EmbeddingPage()),
              );
            },
          ),
          ListTile(
            title: const Text('RAG'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RAGPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Chat'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Vision'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VisionPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
