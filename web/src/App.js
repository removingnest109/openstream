import { useEffect, useRef, useState } from 'react';
import './App.css';
import logoSvg from './logo.svg';
import SidebarNav from './components/SidebarNav';
import TrackList from './components/TrackList';
import AlbumList from './components/AlbumList';
import ArtistList from './components/ArtistList';
import PlaylistList from './components/PlaylistList';
import TrackEditModal from './components/TrackEditModal';
import SettingsForm from './components/SettingsForm';
import PlayerBar from './components/PlayerBar';

function App() {
  const isMobile = typeof window !== 'undefined' && window.matchMedia && window.matchMedia('(max-width: 600px)').matches;
  const [tracks, setTracks] = useState([]);
  const [playlists, setPlaylists] = useState([]);
  const [selectedPlaylist, setSelectedPlaylist] = useState(null);
  const [currentTrackIndex, setCurrentTrackIndex] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [shuffle, setShuffle] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration] = useState(0);
  const [loop, setLoop] = useState(false);
  const [volume, setVolume] = useState(1);
  const [isMuted, setIsMuted] = useState(false);
  const [albums, setAlbums] = useState([]);
  const [artists, setArtists] = useState([]);
  const [view, setView] = useState('library');
  const [selectedAlbum, setSelectedAlbum] = useState(null);
  const [selectedArtist, setSelectedArtist] = useState(null);
  const [primaryColor, setPrimaryColor] = useState(getComputedStyle(document.documentElement).getPropertyValue('--primary-color').trim() || '#e5e743');
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [trackMenuOpen, setTrackMenuOpen] = useState(null); // track.id or null
  const [editingTrack, setEditingTrack] = useState(null);
  const [editForm, setEditForm] = useState({ title: '', album: '', artist: '' });
  const [editSaving, setEditSaving] = useState(false);
  const [albumArtUploading, setAlbumArtUploading] = useState({});
  const [albumArtUrlMap, setAlbumArtUrlMap] = useState({});
  const [albumCoverUrlMap, setAlbumCoverUrlMap] = useState({});
  const audioRef = useRef(null);
  const shuffleHistory = useRef([]);

  // Track edit modal logic
  const openEditTrack = (track) => {
    setEditingTrack(track);
    setEditForm({
      title: track.title || '',
      album: track.album?.title || '',
      artist: track.album?.artist?.name || '',
    });
  };
  const handleEditFormChange = (e) => {
    setEditForm({ ...editForm, [e.target.name]: e.target.value });
  };
  const saveEditTrack = async () => {
    if (!editingTrack) return;
    setEditSaving(true);
    try {
      setEditingTrack(null);
      setEditForm({ title: '', album: '', artist: '' });
      // Refresh tracks
      const updatedTracks = await fetch('/api/tracks').then(r => r.json());
      setTracks(updatedTracks);
    } catch (err) {
      alert('Failed to update track: ' + err.message);
    } finally {
      setEditSaving(false);
    }
  };

  // Album art upload handler
  const handleAlbumArtUpload = async (albumId, file) => {
    if (!file) return;
    setAlbumArtUploading(a => ({ ...a, [albumId]: true }));
    try {
      const formData = new FormData();
      formData.append('file', file);
      await fetch(`/api/albums/${albumId}/art`, {
        method: 'POST',
        body: formData
      });
      // Refresh tracks and albums
      const updatedTracks = await fetch('/api/tracks').then(r => r.json());
      setTracks(updatedTracks);
    } catch (err) {
      alert('Failed to upload album art: ' + err.message);
    } finally {
      setAlbumArtUploading(a => ({ ...a, [albumId]: false }));
    }
  };

  useEffect(() => {
    document.documentElement.style.setProperty('--primary-color', primaryColor);
  }, [primaryColor]);

  useEffect(() => {
    fetch('/api/tracks')
      .then(res => res.json())
      .then(setTracks)
      .catch(err => console.error('Failed to load tracks:', err));
    fetch('/api/playlists')
      .then(res => res.json())
      .then(setPlaylists)
      .catch(err => console.error('Failed to load playlists:', err));
  }, []);


  useEffect(() => {
    const uniqueAlbums = {};
    const uniqueArtists = {};
    const artMap = {};
    const albumMap = {};
    tracks.forEach(track => {
      const album = track.album;
      const artist = album?.artist;
      if (album && !uniqueAlbums[album.id]) uniqueAlbums[album.id] = album;
      if (artist && !uniqueArtists[artist.id]) uniqueArtists[artist.id] = artist;
      if (album && album.albumArtPath) {
        // Prevent double /api/albumart/ prefix
        const artPath = album.albumArtPath.startsWith('/api/albumart/')
          ? album.albumArtPath
          : `/api/albumart/${album.albumArtPath}`;
        artMap[track.id] = artPath;
      } else {
        artMap[track.id] = logoSvg;
      }
    });
    Object.values(uniqueAlbums).forEach(album => {
      if (album.albumArtPath) {
        const artPath = album.albumArtPath.startsWith('/api/albumart/')
          ? album.albumArtPath
          : `/api/albumart/${album.albumArtPath}`;
        albumMap[album.id] = artPath;
      } else {
        albumMap[album.id] = logoSvg;
      }
    });
    setAlbums(Object.values(uniqueAlbums));
    setArtists(Object.values(uniqueArtists));
    setAlbumArtUrlMap(artMap);
    setAlbumCoverUrlMap(albumMap);
  }, [tracks]);

  useEffect(() => {
    if (audioRef.current) audioRef.current.volume = isMuted ? 0 : volume;
  }, [volume, isMuted]);

  useEffect(() => {
    if (audioRef.current) audioRef.current[isPlaying ? 'play' : 'pause']();
  }, [isPlaying, currentTrackIndex]);

  const playTrack = (index) => {
    setCurrentTrackIndex(index);
    setCurrentTime(0);
    setIsPlaying(true);
  };
  const toggleShuffle = () => {
    shuffleHistory.current = [];
    setShuffle(!shuffle);
  };
  const nextTrack = () => {
    if (!tracks.length) return;
    if (shuffle) {
      shuffleHistory.current.push(currentTrackIndex);
      const available = tracks.map((_, i) => i).filter(i => i !== currentTrackIndex);
      const randomIndex = available[Math.floor(Math.random() * available.length)];
      playTrack(randomIndex);
    } else {
      const nextIndex = (currentTrackIndex + 1) % tracks.length;
      playTrack(nextIndex);
    }
  };
  const prevTrack = () => {
    if (!tracks.length) return;
    if (shuffle && shuffleHistory.current.length > 0) {
      const prevIndex = shuffleHistory.current.pop();
      playTrack(prevIndex);
    } else {
      const prevIndex = (currentTrackIndex - 1 + tracks.length) % tracks.length;
      playTrack(prevIndex);
    }
  };
  const handleSeek = (e) => {
    const seekTime = parseFloat(e.target.value);
    audioRef.current.currentTime = seekTime;
    setCurrentTime(seekTime);
  };
  const handleFileUpload = (e) => {
    const files = e.target.files;
    if (!files.length) return;
    const formData = new FormData();
    Array.from(files).forEach(file => {
      formData.append('file', file);
    });
    fetch('/api/tracks/upload', {
      method: 'POST',
      body: formData,
    })
      .then(res => {
        if (res.ok) {
          fetch('/api/tracks')
            .then(res => res.json())
            .then(setTracks);
        } else {
          alert('Failed to upload tracks');
        }
      })
      .catch(err => {
        console.error('Failed to upload tracks:', err);
        alert('Failed to upload tracks');
      });
  };
  const formatTime = (t) => {
    const m = Math.floor(t / 60).toString().padStart(1, '0');
    const s = Math.floor(t % 60).toString().padStart(2, '0');
    return `${m}:${s}`;
  };
  const currentTrack = tracks[currentTrackIndex];
  
  return (
    <div className="app-container" style={{ height: '100dvh', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <button
        className={`sidebar-toggle nav-button${sidebarOpen ? '' : ''}`}
        onClick={() => setSidebarOpen(!sidebarOpen)}
        title={sidebarOpen ? 'Hide Sidebar' : 'Show Sidebar'}
        style={{
          position: 'fixed',
          top: 32,
          left: sidebarOpen ? 20 : 16,
          zIndex: 100,
          width: 36,
          height: 36,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: 0,
          transition: 'left 0.2s, top 0.2s',
        }}
      >
        {/* Use icon from react-icons/fa if needed */}
        <span>&#9776;</span>
      </button>
      <div className="app-layout" style={{ marginLeft: sidebarOpen ? 80 : 0, transition: 'margin-left 0.2s', flex: 1, overflow: 'auto', paddingBottom: 80, boxSizing: 'border-box' }}>
        {sidebarOpen && (
          <SidebarNav
            view={view}
            setView={setView}
            setSelectedAlbum={setSelectedAlbum}
            setSelectedArtist={setSelectedArtist}
            setSelectedPlaylist={setSelectedPlaylist}
            sidebarOpen={sidebarOpen}
            setSidebarOpen={setSidebarOpen}
          />
        )}
        {view === 'library' && (
          <TrackList
            tracks={tracks}
            selectedPlaylist={selectedPlaylist}
            selectedAlbum={selectedAlbum}
            selectedArtist={selectedArtist}
            isMobile={isMobile}
            currentTrackIndex={currentTrackIndex}
            playTrack={playTrack}
            albumArtUrlMap={albumArtUrlMap}
            logoSvg={logoSvg}
            trackMenuOpen={trackMenuOpen}
            setTrackMenuOpen={setTrackMenuOpen}
            openEditTrack={openEditTrack}
          />
        )}
        {view === 'playlists' && (
          <PlaylistList
            playlists={playlists}
            tracks={tracks}
            setSelectedPlaylist={setSelectedPlaylist}
            setView={setView}
            setPlaylists={setPlaylists}
          />
        )}
        {view === 'albums' && (
          <AlbumList
            albums={albums}
            selectedArtist={selectedArtist}
            albumCoverUrlMap={albumCoverUrlMap}
            logoSvg={logoSvg}
            albumArtUploading={albumArtUploading}
            handleAlbumArtUpload={handleAlbumArtUpload}
            setSelectedAlbum={setSelectedAlbum}
            setView={setView}
          />
        )}
        {view === 'artists' && (
          <ArtistList
            artists={artists}
            albums={albums}
            albumCoverUrlMap={albumCoverUrlMap}
            logoSvg={logoSvg}
            setSelectedArtist={setSelectedArtist}
            setView={setView}
          />
        )}
        {view === 'settings' && (
          <div className="settings">
            <h1 className="app-title">Settings</h1>
            <SettingsForm
              primaryColor={primaryColor}
              setPrimaryColor={setPrimaryColor}
              handleFileUpload={handleFileUpload}
              handleRescan={() => {
                fetch('/api/ingestion/scan', { method: 'POST' })
                  .then(res => {
                    if (res.ok) {
                      alert('Library rescan started');
                      fetch('/api/tracks')
                        .then(res => res.json())
                        .then(setTracks);
                    } else {
                      alert('Failed to start rescan');
                    }
                  })
                  .catch(err => console.error('Failed to start rescan:', err));
              }}
            />
          </div>
        )}
        <TrackEditModal
          editingTrack={editingTrack}
          editForm={editForm}
          handleEditFormChange={handleEditFormChange}
          saveEditTrack={saveEditTrack}
          editSaving={editSaving}
          setEditingTrack={setEditingTrack}
        />
      </div>
      <PlayerBar
        currentTrack={currentTrack}
        isMobile={isMobile}
        audioRef={audioRef}
        loop={loop}
        shuffle={shuffle}
        isPlaying={isPlaying}
        currentTime={currentTime}
        duration={duration}
        volume={volume}
        isMuted={isMuted}
        formatTime={formatTime}
        toggleShuffle={toggleShuffle}
        prevTrack={prevTrack}
        nextTrack={nextTrack}
        setIsPlaying={setIsPlaying}
        setLoop={setLoop}
        setIsMuted={setIsMuted}
        setVolume={setVolume}
        handleSeek={handleSeek}
      />
    </div>
  );
}

export default App;
