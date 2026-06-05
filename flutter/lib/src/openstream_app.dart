import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'openstream_controller.dart';

const _selectedTabKey = 'openstream.selectedTab';
const _accentPickerCollapsedKey = 'openstream.accentPickerCollapsed';

Future<void> _showServerManagerSheet(
  BuildContext context,
  OpenStreamController controller,
) async {
  final nameController = TextEditingController();
  final urlController = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Servers',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: controller.servers.length,
                    itemBuilder: (context, index) {
                      final server = controller.servers[index];
                      return ListTile(
                        title: Text(server.name),
                        subtitle: Text(server.baseUrl),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit server',
                              onPressed: () async {
                                nameController.text = server.name;
                                urlController.text = server.baseUrl;
                                await controller.removeServer(index);
                                setState(() {});
                              },
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete server',
                              onPressed: () async {
                                await controller.removeServer(index);
                                setState(() {});
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Server name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL (e.g. http://192.168.1.20:9090)',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final url = urlController.text.trim();
                    if (name.isEmpty || url.isEmpty) {
                      return;
                    }
                    await controller.addServer(
                      ServerConfig(name: name, baseUrl: url),
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add server'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class OpenStreamApp extends StatelessWidget {
  const OpenStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OpenStreamController>(
      create: (_) => OpenStreamController(),
      child: const _AppShell(),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell();

  ThemeData _buildTheme({
    required Color seedColor,
    required Brightness brightness,
  }) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final neutralSurface = brightness == Brightness.dark
        ? const Color(0xFF121417)
        : const Color(0xFFF7F8FA);
    final scheme = baseScheme.copyWith(surface: neutralSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: neutralSurface,
      canvasColor: neutralSurface,
      appBarTheme: AppBarTheme(
        backgroundColor: neutralSurface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(surfaceTintColor: Colors.transparent),
      dialogTheme: const DialogThemeData(surfaceTintColor: Colors.transparent),
      bottomSheetTheme: const BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: neutralSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OpenStreamController>(
      builder: (context, controller, _) {
        final color = Color(controller.seedColorValue);
        return MaterialApp(
          title: 'OpenStream',
          debugShowCheckedModeBanner: false,
          themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
          theme: _buildTheme(seedColor: color, brightness: Brightness.light),
          darkTheme: _buildTheme(seedColor: color, brightness: Brightness.dark),
          home: const _HomePage(),
        );
      },
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  int _tabIndex = 0;
  bool _promptedForServer = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreSelectedTab();
  }

  Future<void> _restoreSelectedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTab = prefs.getInt(_selectedTabKey) ?? 0;
    if (!mounted) {
      return;
    }
    setState(() {
      _tabIndex = savedTab.clamp(0, 4);
    });
  }

  Future<void> _saveSelectedTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedTabKey, index);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OpenStreamController>();

    if (!kIsWeb &&
        !controller.isBooting &&
        controller.servers.isEmpty &&
        !_promptedForServer) {
      _promptedForServer = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Add your first server'),
            content: const Text(
              'No server is configured yet. Add your OpenStream server address to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _showServerManagerSheet(context, controller);
                },
                child: const Text('Add server'),
              ),
            ],
          ),
        );
      });
    }

    if (controller.isBooting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenStream'),
        actions: [
          if (!kIsWeb) _ServerPicker(controller: controller),
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (controller.error != null)
            MaterialBanner(
              content: Text(controller.error!),
              actions: [
                TextButton(
                  onPressed: controller.refreshAll,
                  child: const Text('Retry'),
                ),
              ],
            ),
          if (controller.isLoading) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search tracks, artists, albums',
              leading: const Icon(Icons.search),
              trailing: [
                IconButton(
                  onPressed: () {
                    _searchController.clear();
                    controller.search('');
                  },
                  icon: const Icon(Icons.clear),
                ),
              ],
              onSubmitted: controller.search,
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _LibraryTab(controller: controller),
                _AlbumsTab(controller: controller),
                _ArtistsTab(controller: controller),
                _PlaylistsTab(controller: controller),
                _SettingsTab(controller: controller),
              ],
            ),
          ),
          _PlayerBar(controller: controller),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _tabIndex = index;
          });
          _saveSelectedTab(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music),
            label: 'Library',
          ),
          NavigationDestination(icon: Icon(Icons.album), label: 'Albums'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Artists'),
          NavigationDestination(
            icon: Icon(Icons.playlist_play),
            label: 'Playlists',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class _ServerPicker extends StatelessWidget {
  const _ServerPicker({required this.controller});

  final OpenStreamController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.servers.isEmpty) {
      return IconButton(
        tooltip: 'Add server',
        onPressed: () => _showServerManagerSheet(context, controller),
        icon: const Icon(Icons.add_link),
      );
    }

    return Row(
      children: [
        DropdownButton<int>(
          value: controller.activeServerIndex.clamp(
            0,
            controller.servers.isEmpty ? 0 : controller.servers.length - 1,
          ),
          hint: const Text('Server'),
          items: [
            for (var i = 0; i < controller.servers.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text(controller.servers[i].name),
              ),
          ],
          onChanged: (index) {
            if (index != null) {
              controller.switchServer(index);
            }
          },
        ),
        IconButton(
          tooltip: 'Manage servers',
          onPressed: () => _showServerManagerSheet(context, controller),
          icon: const Icon(Icons.dns),
        ),
      ],
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({required this.controller});

  final OpenStreamController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.tracks.isEmpty) {
      return const Center(child: Text('No tracks found'));
    }

    return ListView.builder(
      itemCount: controller.tracks.length,
      itemBuilder: (context, index) {
        final track = controller.tracks[index];
        final artUrl = controller.albumArtUrl(track.album.albumArtPath);
        final activeTrack =
            controller.queueIndex >= 0 &&
                controller.queueIndex < controller.queue.length
            ? controller.queue[controller.queueIndex]
            : null;
        final selected = activeTrack?.id == track.id;

        return ListTile(
          selected: selected,
          leading: CircleAvatar(
            backgroundImage: artUrl.isNotEmpty ? NetworkImage(artUrl) : null,
            child: artUrl.isEmpty ? const Icon(Icons.music_note) : null,
          ),
          title: Text(track.title),
          subtitle: Text('${track.artistName} • ${track.album.title}'),
          onTap: () =>
              controller.playTracks(controller.tracks, startIndex: index),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditTrackDialog(context, controller, track);
              }
              if (value == 'delete') {
                _showDeleteDialog(context, controller, track.id);
              }
              if (value == 'add_to_playlist') {
                _showAddToPlaylistDialog(context, controller, track);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit metadata')),
              PopupMenuItem(value: 'delete', child: Text('Delete track')),
              PopupMenuItem(
                value: 'add_to_playlist',
                child: Text('Add to playlist'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditTrackDialog(
    BuildContext context,
    OpenStreamController controller,
    Track track,
  ) async {
    final titleCtrl = TextEditingController(text: track.title);
    final albumCtrl = TextEditingController(text: track.album.title);
    final artistCtrl = TextEditingController(text: track.artistName);
    final albumArtistsCtrl = TextEditingController(
      text: track.album.displayArtistNames,
    );

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit track metadata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: albumCtrl,
              decoration: const InputDecoration(labelText: 'Album'),
            ),
            TextField(
              controller: artistCtrl,
              decoration: const InputDecoration(labelText: 'Artist'),
            ),
            TextField(
              controller: albumArtistsCtrl,
              decoration: const InputDecoration(
                labelText: 'Album artists (comma separated)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await controller.updateTrack(
                id: track.id,
                title: titleCtrl.text.trim(),
                albumTitle: albumCtrl.text.trim(),
                artistName: artistCtrl.text.trim(),
                albumArtistNames: albumArtistsCtrl.text.trim(),
              );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    OpenStreamController controller,
    String trackId,
  ) async {
    var deleteFile = false;
    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Delete track'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Do you want to remove this track?'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: deleteFile,
                onChanged: (value) =>
                    setState(() => deleteFile = value ?? false),
                title: const Text('Also delete file on disk'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.deleteTrack(trackId, deleteFile: deleteFile);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddToPlaylistDialog(
    BuildContext context,
    OpenStreamController controller,
    Track track,
  ) async {
    if (controller.playlists.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No playlists yet'),
          content: const Text('Create a playlist first, then add tracks to it.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    int selectedPlaylistId = controller.playlists.first.id;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add to playlist'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose a playlist for "${track.title}".',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final playlist in controller.playlists)
                        RadioListTile<int>(
                          value: playlist.id,
                          groupValue: selectedPlaylistId,
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              selectedPlaylistId = value;
                            });
                          },
                          title: Text(playlist.name),
                          subtitle: Text('${playlist.tracks.length} tracks'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.addTrackToPlaylist(
                  playlistId: selectedPlaylistId,
                  trackId: track.id,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add track'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumsTab extends StatefulWidget {
  const _AlbumsTab({required this.controller});

  final OpenStreamController controller;

  @override
  State<_AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<_AlbumsTab> {
  Album? _selectedAlbum;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final selectedAlbum = _selectedAlbum;

    if (selectedAlbum != null) {
      final tracks =
          controller.tracks
              .where((track) => track.album.id == selectedAlbum.id)
              .toList()
            ..sort((a, b) => a.trackNumber.compareTo(b.trackNumber));

      return Column(
        children: [
          ListTile(
            leading: IconButton(
              tooltip: 'Back to albums',
              onPressed: () => setState(() => _selectedAlbum = null),
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(selectedAlbum.title),
            subtitle: Text(selectedAlbum.displayArtistNames),
            trailing: FilledButton.tonalIcon(
              onPressed: tracks.isEmpty
                  ? null
                  : () => controller.playTracks(tracks),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play all'),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return ListTile(
                  leading: Text(
                    track.trackNumber > 0
                        ? '${track.trackNumber}'
                        : '${index + 1}',
                  ),
                  title: Text(track.title),
                  subtitle: Text(track.artistName),
                  onTap: () => controller.playTracks(tracks, startIndex: index),
                );
              },
            ),
          ),
        ],
      );
    }

    final albums = controller.albums;
    if (albums.isEmpty) {
      return const Center(child: Text('No albums'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 240)
            .floor()
            .clamp(2, 8)
            .toInt();

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.95,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            final art = controller.albumArtUrl(album.albumArtPath);
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(() => _selectedAlbum = album),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: art.isEmpty
                          ? const Center(child: Icon(Icons.album, size: 54))
                          : SizedBox.expand(
                              child: Image.network(art, fit: BoxFit.cover),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                      child: Text(
                        album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              album.displayArtistNames,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Upload album art',
                            onPressed: () async {
                              await controller.uploadAlbumArt(album.id);
                            },
                            icon: const Icon(Icons.image_outlined),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ArtistsTab extends StatefulWidget {
  const _ArtistsTab({required this.controller});

  final OpenStreamController controller;

  @override
  State<_ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends State<_ArtistsTab> {
  Artist? _selectedArtist;
  Album? _selectedAlbum;

  List<String> _splitArtistLabel(String value) {
    return value
        .split(RegExp(r'\s*[,;|/&]\s*'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  bool _trackHasArtist(Track track, Artist artist) {
    final collaborators = track.artists.isNotEmpty
        ? track.artists
        : track.album.artists;
    if (collaborators.isNotEmpty) {
      return collaborators.any((item) => item.id == artist.id);
    }

    final normalizedTarget = artist.name.trim().toLowerCase();
    final flattened = _splitArtistLabel(
      track.artistName,
    ).map((name) => name.toLowerCase()).toList();
    if (flattened.isNotEmpty) {
      return flattened.contains(normalizedTarget);
    }
    return track.artistName.trim().toLowerCase() == normalizedTarget;
  }

  int _primaryTrackArtistId(Track track) {
    if (track.artists.isNotEmpty) {
      return track.artists.first.id;
    }
    if (track.album.artists.isNotEmpty) {
      return track.album.artists.first.id;
    }
    return track.album.artist.id;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final artists = controller.artists;
    final selectedArtist = _selectedArtist;
    final selectedAlbum = _selectedAlbum;

    if (selectedArtist != null && selectedAlbum != null) {
      final tracks = controller.tracks.where((track) {
        return track.album.id == selectedAlbum.id &&
            _trackHasArtist(track, selectedArtist);
      }).toList()..sort((a, b) => a.trackNumber.compareTo(b.trackNumber));

      return Column(
        children: [
          ListTile(
            leading: IconButton(
              tooltip: 'Back to albums',
              onPressed: () => setState(() => _selectedAlbum = null),
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(selectedAlbum.title),
            subtitle: Text('${selectedArtist.name} • ${tracks.length} tracks'),
            trailing: FilledButton.tonalIcon(
              onPressed: tracks.isEmpty
                  ? null
                  : () => controller.playTracks(tracks),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play all'),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return ListTile(
                  leading: Text(
                    track.trackNumber > 0
                        ? '${track.trackNumber}'
                        : '${index + 1}',
                  ),
                  title: Text(track.title),
                  subtitle: Text(track.artistName),
                  onTap: () => controller.playTracks(tracks, startIndex: index),
                );
              },
            ),
          ),
        ],
      );
    }

    if (selectedArtist != null) {
      final artistTracks = controller.tracks
          .where((track) => _trackHasArtist(track, selectedArtist))
          .toList();

      final primaryAlbumMap = <int, Album>{};
      final appearsOnAlbumMap = <int, Album>{};
      for (final track in artistTracks) {
        if (_primaryTrackArtistId(track) == selectedArtist.id) {
          primaryAlbumMap[track.album.id] = track.album;
        } else {
          appearsOnAlbumMap[track.album.id] = track.album;
        }
      }

      final albums = primaryAlbumMap.values.toList()
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      final appearsOnAlbums = appearsOnAlbumMap.values.toList()
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      final totalAlbumCount = albums.length + appearsOnAlbums.length;

      return Column(
        children: [
          ListTile(
            leading: IconButton(
              tooltip: 'Back to artists',
              onPressed: () => setState(() {
                _selectedArtist = null;
                _selectedAlbum = null;
              }),
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(selectedArtist.name),
            subtitle: Text('$totalAlbumCount albums'),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                if (albums.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(
                      'Albums',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final album in albums)
                    ListTile(
                      leading: const Icon(Icons.album),
                      title: Text(album.title),
                      subtitle: Text(album.displayArtistNames),
                      onTap: () => setState(() => _selectedAlbum = album),
                    ),
                ],
                if (appearsOnAlbums.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(
                      'Appears on',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final album in appearsOnAlbums)
                    ListTile(
                      leading: const Icon(Icons.library_music),
                      title: Text(album.title),
                      subtitle: Text(album.displayArtistNames),
                      onTap: () => setState(() => _selectedAlbum = album),
                    ),
                ],
                if (albums.isEmpty && appearsOnAlbums.isEmpty)
                  const ListTile(
                    title: Text('No albums found for this artist'),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    if (artists.isEmpty) {
      return const Center(child: Text('No artists'));
    }

    return ListView.builder(
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(artist.name),
          subtitle: Text(
            artist.primaryAlbumCount == 0
                ? '${artist.primaryAlbumCount} albums • appears on ${artist.trackAppearanceCount} tracks'
                : '${artist.primaryAlbumCount} albums',
          ),
          onTap: () => setState(() {
            _selectedArtist = artist;
            _selectedAlbum = null;
          }),
        );
      },
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab({required this.controller});

  final OpenStreamController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: () => _showCreatePlaylistDialog(context, controller),
                icon: const Icon(Icons.add),
                label: const Text('New playlist'),
              ),
            ],
          ),
        ),
        Expanded(
          child: controller.playlists.isEmpty
              ? const Center(child: Text('No playlists yet'))
              : ListView.builder(
                  itemCount: controller.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = controller.playlists[index];
                    return ExpansionTile(
                      title: Text(playlist.name),
                      subtitle: Text('${playlist.tracks.length} tracks'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit playlist',
                            onPressed: () =>
                                _showEditPlaylistDialog(context, controller, playlist),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete playlist',
                            onPressed: () =>
                                _showDeletePlaylistDialog(context, controller, playlist),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      children: [
                        for (var i = 0; i < playlist.tracks.length; i++)
                          ListTile(
                            dense: true,
                            title: Text(playlist.tracks[i].title),
                            subtitle: Text(playlist.tracks[i].artistName),
                            onTap: () => controller.playTracks(
                              playlist.tracks,
                              startIndex: i,
                            ),
                          ),
                        OverflowBar(
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  controller.playTracks(playlist.tracks),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Play all'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showCreatePlaylistDialog(
    BuildContext context,
    OpenStreamController controller,
  ) async {
    final nameCtrl = TextEditingController();
    final selected = <String>{};

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create playlist'),
          content: SizedBox(
            width: 500,
            height: 450,
            child: Column(
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Playlist name'),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final track in controller.tracks)
                        CheckboxListTile(
                          value: selected.contains(track.id),
                          onChanged: (value) {
                            setState(() {
                              if (value ?? false) {
                                selected.add(track.id);
                              } else {
                                selected.remove(track.id);
                              }
                            });
                          },
                          title: Text(track.title),
                          subtitle: Text(track.artistName),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty || nameCtrl.text.trim().isEmpty
                  ? null
                  : () async {
                      await controller.createPlaylist(
                        name: nameCtrl.text.trim(),
                        trackIds: selected.toList(),
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditPlaylistDialog(
    BuildContext context,
    OpenStreamController controller,
    Playlist playlist,
  ) async {
    final nameCtrl = TextEditingController(text: playlist.name);

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit playlist'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final nextName = nameCtrl.text.trim();
              if (nextName.isEmpty) {
                return;
              }
              await controller.updatePlaylist(
                playlistId: playlist.id,
                name: nextName,
              );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeletePlaylistDialog(
    BuildContext context,
    OpenStreamController controller,
    Playlist playlist,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete playlist'),
        content: Text('Delete "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await controller.deletePlaylist(playlist.id);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({required this.controller});

  final OpenStreamController controller;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  static const int _defaultAccentColor = 0xFF6D4AFF;

  final TextEditingController _hexController = TextEditingController();

  bool _isAccentPickerCollapsed = false;
  int _red = 0x6D;
  int _green = 0x4A;
  int _blue = 0xFF;
  double _hue = 0;
  double _saturation = 0;
  double _value = 1;

  @override
  void initState() {
    super.initState();
    _syncFromSeedColor(widget.controller.seedColorValue);
    _restoreAccentPickerCollapsed();
  }

  Future<void> _restoreAccentPickerCollapsed() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_accentPickerCollapsedKey) ?? false;
    if (!mounted) {
      return;
    }
    setState(() {
      _isAccentPickerCollapsed = saved;
    });
  }

  Future<void> _setAccentPickerCollapsed(bool collapsed) async {
    setState(() {
      _isAccentPickerCollapsed = collapsed;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_accentPickerCollapsedKey, collapsed);
  }

  @override
  void didUpdateWidget(covariant _SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.seedColorValue != _currentColorValue) {
      _syncFromSeedColor(widget.controller.seedColorValue);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  int get _currentColorValue =>
      0xFF000000 | (_red << 16) | (_green << 8) | _blue;

  void _syncFromSeedColor(int colorValue) {
    final color = Color(colorValue);
    final hsv = HSVColor.fromColor(color);
    _red = color.red;
    _green = color.green;
    _blue = color.blue;
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _hexController.text = _hexFromRgb(_red, _green, _blue);
  }

  String _hexFromRgb(int r, int g, int b) {
    return '${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  Future<void> _applyRgb({
    required int red,
    required int green,
    required int blue,
  }) async {
    setState(() {
      _red = red.clamp(0, 255);
      _green = green.clamp(0, 255);
      _blue = blue.clamp(0, 255);
      final hsv = HSVColor.fromColor(Color(_currentColorValue));
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
      _hexController.text = _hexFromRgb(_red, _green, _blue);
    });
    unawaited(widget.controller.setSeedColor(_currentColorValue));
  }

  void _applyHsv({
    required double hue,
    required double saturation,
    required double value,
  }) {
    final normalizedHue = hue.clamp(0.0, 360.0);
    final normalizedSaturation = saturation.clamp(0.0, 1.0);
    final normalizedValue = value.clamp(0.0, 1.0);
    final color = HSVColor.fromAHSV(
      1,
      normalizedHue,
      normalizedSaturation,
      normalizedValue,
    ).toColor();

    setState(() {
      _hue = normalizedHue;
      _saturation = normalizedSaturation;
      _value = normalizedValue;
      _red = color.red;
      _green = color.green;
      _blue = color.blue;
      _hexController.text = _hexFromRgb(_red, _green, _blue);
    });

    unawaited(widget.controller.setSeedColor(_currentColorValue));
  }

  Future<void> _applyHexIfValid(String value) async {
    final normalized = value.trim().toUpperCase();
    if (normalized.length != 6) {
      return;
    }
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) {
      return;
    }
    await _applyRgb(
      red: (parsed >> 16) & 0xFF,
      green: (parsed >> 8) & 0xFF,
      blue: parsed & 0xFF,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final previewColor = Color(_currentColorValue);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Dark mode'),
          subtitle: const Text('Toggle light/dark theme'),
          value: controller.darkMode,
          onChanged: controller.setDarkMode,
        ),
        SwitchListTile(
          title: const Text('True shuffle'),
          subtitle: const Text(
            'When on, skip picks a completely random song each time. '
            'When off, shuffle randomizes the list and plays through it in order.',
          ),
          value: controller.trueShuffle,
          onChanged: controller.setTrueShuffle,
        ),
        const SizedBox(height: 10),
        const Text(
          'Accent color',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: previewColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _hexController,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'Hex color',
                              prefixText: '#',
                              counterText: '',
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9a-fA-F]'),
                              ),
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onChanged: (value) async {
                              final normalized = value.toUpperCase();
                              if (normalized != value) {
                                _hexController.value = _hexController.value
                                    .copyWith(
                                      text: normalized,
                                      selection: TextSelection.collapsed(
                                        offset: normalized.length,
                                      ),
                                    );
                              }
                              await _applyHexIfValid(normalized);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            await _applyRgb(
                              red: (_defaultAccentColor >> 16) & 0xFF,
                              green: (_defaultAccentColor >> 8) & 0xFF,
                              blue: _defaultAccentColor & 0xFF,
                            );
                          },
                          child: const Text('Reset'),
                        ),
                        IconButton(
                          tooltip: _isAccentPickerCollapsed
                              ? 'Expand color picker'
                              : 'Minimize color picker',
                          onPressed: () {
                            _setAccentPickerCollapsed(
                              !_isAccentPickerCollapsed,
                            );
                          },
                          icon: Icon(
                            _isAccentPickerCollapsed
                                ? Icons.expand_more
                                : Icons.expand_less,
                          ),
                        ),
                      ],
                    ),
                    if (!_isAccentPickerCollapsed) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 220,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 220,
                              height: 220,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final hueColor = HSVColor.fromAHSV(
                                    1,
                                    _hue,
                                    1,
                                    1,
                                  ).toColor();
                                  final width = constraints.maxWidth;
                                  final height = constraints.maxHeight;
                                  final markerX = _saturation * width;
                                  final markerY = (1 - _value) * height;

                                  void handlePosition(Offset localPosition) {
                                    final nextSaturation =
                                        (localPosition.dx / width).clamp(
                                          0.0,
                                          1.0,
                                        );
                                    final nextValue =
                                        (1 - (localPosition.dy / height)).clamp(
                                          0.0,
                                          1.0,
                                        );
                                    _applyHsv(
                                      hue: _hue,
                                      saturation: nextSaturation,
                                      value: nextValue,
                                    );
                                  }

                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanDown: (details) =>
                                        handlePosition(details.localPosition),
                                    onPanUpdate: (details) =>
                                        handlePosition(details.localPosition),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: <Color>[
                                                    Colors.white,
                                                    hueColor,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned.fill(
                                            child: DecoratedBox(
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: <Color>[
                                                    Colors.transparent,
                                                    Colors.black,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: markerX - 8,
                                            top: markerY - 8,
                                            child: IgnorePointer(
                                              child: Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Colors.black54,
                                                      blurRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 28,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final height = constraints.maxHeight;
                                  final markerY = (_hue / 360) * height;

                                  void handleHue(Offset localPosition) {
                                    final nextHue =
                                        ((localPosition.dy / height) * 360)
                                            .clamp(0.0, 360.0);
                                    _applyHsv(
                                      hue: nextHue,
                                      saturation: _saturation,
                                      value: _value,
                                    );
                                  }

                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanDown: (details) =>
                                        handleHue(details.localPosition),
                                    onPanUpdate: (details) =>
                                        handleHue(details.localPosition),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: const <Color>[
                                                    Color(0xFFFF0000),
                                                    Color(0xFFFFFF00),
                                                    Color(0xFF00FF00),
                                                    Color(0xFF00FFFF),
                                                    Color(0xFF0000FF),
                                                    Color(0xFFFF00FF),
                                                    Color(0xFFFF0000),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 2,
                                            right: 2,
                                            top: markerY - 2,
                                            child: IgnorePointer(
                                              child: Container(
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                  border: Border.all(
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 28),
        if (kIsWeb) ...[
          TextFormField(
            initialValue: controller.webServerUrl,
            decoration: InputDecoration(
              labelText: 'Server URL',
              hintText: Uri.base.origin,
            ),
            onFieldSubmitted: (value) => controller.setWebServer(value.trim()),
          ),
          const SizedBox(height: 8),
          Text(
            'Press Enter to save and reconnect.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        FilledButton.tonalIcon(
          onPressed: () async {
            await controller.uploadTrack();
          },
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload track'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: controller.rescanLibrary,
          icon: const Icon(Icons.sync),
          label: const Text('Rescan library'),
        ),
      ],
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.controller});

  final OpenStreamController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isRestoringPlaybackSession) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [const SizedBox(height: 56)],
        ),
      );
    }

    final isMobilePlatform =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final queue = controller.queue;
    final current =
        controller.queueIndex >= 0 && controller.queueIndex < queue.length
        ? queue[controller.queueIndex]
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: current == null
                    ? const Text('Nothing playing')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${current.artistName} • ${current.album.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
              ),
              IconButton(
                tooltip: 'Shuffle',
                onPressed: () =>
                    controller.setShuffle(!controller.shuffleEnabled),
                icon: Icon(
                  Icons.shuffle,
                  color: controller.shuffleEnabled
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              IconButton(
                tooltip: 'Previous',
                onPressed: controller.previousTrack,
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton.filledTonal(
                tooltip: 'Play/Pause',
                onPressed: controller.togglePlayPause,
                icon: Icon(
                  controller.audioPlayer.playing
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: controller.nextTrack,
                icon: const Icon(Icons.skip_next),
              ),
              IconButton(
                tooltip: 'Loop',
                onPressed: () => controller.setLoop(!controller.loopEnabled),
                icon: Icon(
                  Icons.repeat,
                  color: controller.loopEnabled
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ],
          ),
          StreamBuilder<Duration>(
            stream: controller.audioPlayer.positionStream,
            builder: (context, positionSnapshot) {
              return StreamBuilder<Duration?>(
                stream: controller.audioPlayer.durationStream,
                builder: (context, durationSnapshot) {
                  final currentPosition =
                      positionSnapshot.data ?? Duration.zero;
                  final total = durationSnapshot.data ?? Duration.zero;
                  final max = total.inMilliseconds <= 0
                      ? 1.0
                      : total.inMilliseconds.toDouble();
                  final value = currentPosition.inMilliseconds
                      .clamp(0, max.toInt())
                      .toDouble();

                  return Column(
                    children: [
                      Slider(
                        value: value,
                        max: max,
                        onChanged: (next) {
                          controller.seek(Duration(milliseconds: next.toInt()));
                        },
                      ),
                      Row(
                        children: [
                          Text(_formatDuration(currentPosition)),
                          const Spacer(),
                          if (!isMobilePlatform) ...[
                            SizedBox(
                              width: 120,
                              child: Slider(
                                value: controller.volume,
                                max: 1,
                                onChanged: controller.setVolume,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(_formatDuration(total)),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
