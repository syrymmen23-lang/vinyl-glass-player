import 'dart:ui' as ui;
import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AudioService.init(
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.vinyl_glass_player.channel.audio',
      androidNotificationChannelName: 'Music playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidEnableQueue: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
    builder: () => VinylAudioHandler(),
  );

  runApp(const VinylApp());
}

class VinylApp extends StatelessWidget {
  const VinylApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AudioPlayer _player;
  final ImagePicker _picker = ImagePicker();

  final List<Song> _songs = [
    Song(
      title: 'Midnight Drive',
      artist: 'Night Echo',
      coverUrl:
          'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=900&q=80',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    ),
    Song(
      title: 'Clouds',
      artist: 'Skyline',
      coverUrl:
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    ),
    Song(
      title: 'Golden Hour',
      artist: 'Luna Bay',
      coverUrl:
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=900&q=80',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    ),
  ];

  int _selectedSongIndex = 0;
  int _selectedGradient = 0;
  String? _imagePath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _loadSavedSettings();
    _bindAudioService();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedGradient = prefs.getInt('selected_gradient') ?? 0;
      _imagePath = prefs.getString('selected_image_path');
    });
  }

  Future<void> _bindAudioService() async {
    final currentQueue = _songs
        .map((song) => MediaItem(
              id: song.audioUrl,
              title: song.title,
              artist: song.artist,
              artUri: Uri.parse(song.coverUrl),
              extras: {'audio_url': song.audioUrl},
            ))
        .toList();

    await AudioService.updateQueue(currentQueue);
    await AudioService.updateMediaItem(currentQueue.first);

    AudioService.position.listen((position) {
      if (!mounted) return;
    });
  }

  Future<void> _requestAudioPermission() async {
    if (Platform.isAndroid && await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
    if (Platform.isAndroid && await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> _pickImageFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_image_path', file.path);
    setState(() {
      _imagePath = file.path;
    });
  }

  Future<void> _selectGradient(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_gradient', index);
    setState(() => _selectedGradient = index);
  }

  BoxDecoration _getBackground() {
    final gradients = [
      const LinearGradient(
        colors: [Color(0xFF091B2E), Color(0xFF1D4E89), Color(0xFF8ED1FC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF2d1b69), Color(0xFF7b2cbf), Color(0xFFff7b00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF0f172a), Color(0xFF22c55e), Color(0xFF86efac)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF3b0764), Color(0xFFec4899), Color(0xFFfbbf24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF111827), Color(0xFF0ea5e9), Color(0xFFa78bfa)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF1d1d1d), Color(0xFFb91c1c), Color(0xFFf59e0b)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];

    if (_imagePath != null) {
      return BoxDecoration(
        image: DecorationImage(
          image: FileImage(File(_imagePath!)),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.35),
            BlendMode.darken,
          ),
        ),
      );
    }

    return BoxDecoration(gradient: gradients[_selectedGradient]);
  }

  Future<void> _playSong(int index) async {
    setState(() {
      _selectedSongIndex = index;
    });

    final song = _songs[index];
    await AudioService.playMediaItem(MediaItem(
      id: song.audioUrl,
      title: song.title,
      artist: song.artist,
      artUri: Uri.parse(song.coverUrl),
      extras: {'audio_url': song.audioUrl},
    ));

    await AudioService.play();
    setState(() => _isPlaying = true);
  }

  Future<void> _togglePlayPause() async {
    final state = await AudioService.playbackState.first;
    if (state.playing) {
      await AudioService.pause();
      setState(() => _isPlaying = false);
    } else {
      await AudioService.play();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _prevSong() async {
    final nextIndex =
        (_selectedSongIndex - 1 + _songs.length) % _songs.length;
    await _playSong(nextIndex);
  }

  Future<void> _nextSong() async {
    final nextIndex = (_selectedSongIndex + 1) % _songs.length;
    await _playSong(nextIndex);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = _songs[_selectedSongIndex];

    return Scaffold(
      body: DecoratedBox(
        decoration: _getBackground(),
        child: Container(
          color: Colors.black.withOpacity(0.20),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Vinyl Bloom',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showThemePicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: const Text(
                            '🎨',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        AnimatedVinyl(
                          isPlaying: _isPlaying,
                          coverUrl: currentSong.coverUrl,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          currentSong.title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currentSong.artist,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded, size: 36),
                              color: Colors.white,
                              onPressed: _prevSong,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(60),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                ),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 46,
                                ),
                                color: Colors.white,
                                onPressed: _togglePlayPause,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, size: 36),
                              color: Colors.white,
                              onPressed: _nextSong,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: GlassPlaylist(
                    songs: _songs,
                    selectedIndex: _selectedSongIndex,
                    onSongTap: _playSong,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              backdropFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Фон таңдау',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 6,
                    itemBuilder: (_, index) {
                      final gradients = [
                        const LinearGradient(
                          colors: [Color(0xFF091B2E), Color(0xFF1D4E89), Color(0xFF8ED1FC)],
                        ),
                        const LinearGradient(
                          colors: [Color(0xFF2d1b69), Color(0xFF7b2cbf), Color(0xFFff7b00)],
                        ),
                        const LinearGradient(
                          colors: [Color(0xFF0f172a), Color(0xFF22c55e), Color(0xFF86efac)],
                        ),
                        const LinearGradient(
                          colors: [Color(0xFF3b0764), Color(0xFFec4899), Color(0xFFfbbf24)],
                        ),
                        const LinearGradient(
                          colors: [Color(0xFF111827), Color(0xFF0ea5e9), Color(0xFFa78bfa)],
                        ),
                        const LinearGradient(
                          colors: [Color(0xFF1d1d1d), Color(0xFFb91c1c), Color(0xFFf59e0b)],
                        ),
                      ];

                      final selected = _selectedGradient == index;

                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          await _selectGradient(index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 88,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: gradients[index],
                            border: Border.all(
                              color: selected ? Colors.white : Colors.white.withOpacity(0.18),
                              width: selected ? 2.5 : 1,
                            ),
                          ),
                          child: selected
                              ? const Center(
                                  child: Icon(Icons.check, color: Colors.white, size: 30),
                                )
                              : const SizedBox(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _pickImageFromGallery();
                  },
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Галереядан фото таңдау'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.14),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AnimatedVinyl extends StatefulWidget {
  final bool isPlaying;
  final String coverUrl;

  const AnimatedVinyl({
    super.key,
    required this.isPlaying,
    required this.coverUrl,
  });

  @override
  State<AnimatedVinyl> createState() => _AnimatedVinylState();
}

class _AnimatedVinylState extends State<AnimatedVinyl>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedVinyl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Transform.rotate(
          angle: widget.isPlaying ? _controller.value * 2 * 3.14159 : 0,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 270,
            height: 270,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF1d1d1d), Color(0xFF454545)],
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 30,
                  color: Colors.black54,
                  spreadRadius: 8,
                )
              ],
            ),
          ),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: NetworkImage(widget.coverUrl),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 8),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFd1d5db),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class GlassPlaylist extends StatelessWidget {
  final List<Song> songs;
  final int selectedIndex;
  final Function(int) onSongTap;

  const GlassPlaylist({
    super.key,
    required this.songs,
    required this.selectedIndex,
    required this.onSongTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < songs.length; i++)
                GestureDetector(
                  onTap: () => onSongTap(i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedIndex == i
                          ? Colors.white.withOpacity(0.16)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(songs[i].coverUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                songs[i].title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                songs[i].artist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          selectedIndex == i
                              ? Icons.equalizer_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class Song {
  final String title;
  final String artist;
  final String coverUrl;
  final String audioUrl;

  Song({
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.audioUrl,
  });
}

class VinylAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final List<MediaItem> _queue = [];

  VinylAudioHandler() {
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState] ?? AudioProcessingState.idle,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });
  }

  @override
  Future<void> play() async => _player.play();

  @override
  Future<void> pause() async => _player.pause();

  @override
  Future<void> stop() async => _player.stop();

  @override
  Future<void> seek(Duration position) async => _player.seek(position);

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    final url = mediaItem.extras?['audio_url'] as String?;
    if (url == null || url.isEmpty) return;
    await _player.setUrl(url);
    mediaItemQueue.add([mediaItem]);
    queue.add([mediaItem]);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queueItems) async {
    _queue.clear();
    _queue.addAll(queueItems);
    queue.add(_queue);
  }
}
