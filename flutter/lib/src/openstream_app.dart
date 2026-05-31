import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'openstream_controller.dart';

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
                        trailing: IconButton(
                          onPressed: () async {
                            await controller.removeServer(index);
                            setState(() {});
                          },
                          icon: const Icon(Icons.delete_outline),
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

Future<bool> _confirmOpenPickerOnMobile(BuildContext context) async {
  final isMobilePlatform = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (!isMobilePlatform) {
    return true;
  }

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Open file picker?'),
      content: const Text(
        'This will open the system file picker. You can cancel now if you opened this by mistake.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return result ?? false;
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

  @override
  Widget build(BuildContext context) {
    return Consumer<OpenStreamController>(
      builder: (context, controller, _) {
        final color = Color(controller.seedColorValue);
        return MaterialApp(
          title: 'OpenStream',
          debugShowCheckedModeBanner: false,
          themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: color),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: color,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.library_music), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.album), label: 'Albums'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Artists'),
          NavigationDestination(icon: Icon(Icons.playlist_play), label: 'Playlists'),
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
        final activeTrack = controller.queueIndex >= 0 &&
            controller.queueIndex < controller.queue.length
            ? controller.queue[controller.queueIndex]
            : null;
        final selected = activeTrack?.id == track.id;

        return ListTile(
          selected: selected,
          leading: CircleAvatar(
            backgroundImage: artUrl.isNotEmpty ? NetworkImage(artUrl) : null,
            child: artUrl.isEmpty
                ? const Icon(Icons.music_note)
                : null,
          ),
          title: Text(track.title),
          subtitle: Text('${track.artistName} • ${track.album.title}'),
          onTap: () => controller.playTracks(controller.tracks, startIndex: index),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditTrackDialog(context, controller, track);
              }
              if (value == 'delete') {
                _showDeleteDialog(context, controller, track.id);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit metadata')),
              PopupMenuItem(value: 'delete', child: Text('Delete track')),
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
                onChanged: (value) => setState(() => deleteFile = value ?? false),
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
      final tracks = controller.tracks
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
              onPressed: tracks.isEmpty ? null : () => controller.playTracks(tracks),
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
                    track.trackNumber > 0 ? '${track.trackNumber}' : '${index + 1}',
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
        final crossAxisCount =
            (constraints.maxWidth / 240).floor().clamp(2, 8).toInt();

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
                              if (!await _confirmOpenPickerOnMobile(context)) {
                                return;
                              }
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
    final collaborators = track.artists.isNotEmpty ? track.artists : track.album.artists;
    if (collaborators.isNotEmpty) {
      return collaborators.any((item) => item.id == artist.id);
    }

    final normalizedTarget = artist.name.trim().toLowerCase();
    final flattened = _splitArtistLabel(track.artistName)
        .map((name) => name.toLowerCase())
        .toList();
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
        return track.album.id == selectedAlbum.id && _trackHasArtist(track, selectedArtist);
      }).toList()
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
            subtitle: Text('${selectedArtist.name} • ${tracks.length} tracks'),
            trailing: FilledButton.tonalIcon(
              onPressed: tracks.isEmpty ? null : () => controller.playTracks(tracks),
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
                    track.trackNumber > 0 ? '${track.trackNumber}' : '${index + 1}',
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
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      final appearsOnAlbums = appearsOnAlbumMap.values.toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                  const ListTile(title: Text('No albums found for this artist')),
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
                              onPressed: () => controller.playTracks(playlist.tracks),
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
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.controller});

  final OpenStreamController controller;

  static const _swatches = <int>[
    0xFF6D4AFF,
    0xFF00BFA5,
    0xFF42A5F5,
    0xFFFF7043,
    0xFFFFC107,
    0xFFE91E63,
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Dark mode'),
          subtitle: const Text('Toggle light/dark theme'),
          value: controller.darkMode,
          onChanged: controller.setDarkMode,
        ),
        const SizedBox(height: 10),
        const Text(
          'Accent color',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final swatch in _swatches)
              InkWell(
                onTap: () => controller.setSeedColor(swatch),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(swatch),
                  child: controller.seedColorValue == swatch
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              ),
          ],
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
            if (!await _confirmOpenPickerOnMobile(context)) {
              return;
            }
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
    final isMobilePlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final queue = controller.queue;
    final current = controller.queueIndex >= 0 && controller.queueIndex < queue.length
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
                onPressed: () => controller.setShuffle(!controller.shuffleEnabled),
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
                  controller.audioPlayer.playing ? Icons.pause : Icons.play_arrow,
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
                  color:
                      controller.loopEnabled ? Theme.of(context).colorScheme.primary : null,
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
                  final currentPosition = positionSnapshot.data ?? Duration.zero;
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



