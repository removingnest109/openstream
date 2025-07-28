import { useEffect, useRef, useState } from 'react';
import { FaPlay, FaPause, FaStepForward, FaStepBackward, FaRandom, FaRedo, FaVolumeUp, FaVolumeMute, FaMusic, FaCompactDisc, FaUser, FaListUl, FaCog } from 'react-icons/fa';
import './App.css';


function App() {
  // Simple mobile detection
  const isMobile = typeof window !== 'undefined' && window.matchMedia && window.matchMedia('(max-width: 600px)').matches;
  const [tracks, setTracks] = useState([]);
  const [playlists, setPlaylists] = useState([]);
  const [selectedPlaylist, setSelectedPlaylist] = useState(null);
  const [currentTrackIndex, setCurrentTrackIndex] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [shuffle, setShuffle] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
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

  useEffect(() => {
    document.documentElement.style.setProperty('--primary-color', primaryColor);
  }, [primaryColor]);

  const audioRef = useRef(null);
  const shuffleHistory = useRef([]);

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

    tracks.forEach(track => {
      const album = track.album;
      const artist = track.album.artist;

      if (album && !uniqueAlbums[album.id]) {
        uniqueAlbums[album.id] = album;
      }

      if (artist && !uniqueArtists[artist.id]) {
        uniqueArtists[artist.id] = artist;
      }
    });

    setAlbums(Object.values(uniqueAlbums));
    setArtists(Object.values(uniqueArtists));
  }, [tracks]);


  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.volume = isMuted ? 0 : volume;
    }
  }, [volume, isMuted]);


  useEffect(() => {
    if (audioRef.current) {
      audioRef.current[isPlaying ? 'play' : 'pause']();
    }
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
          alert('Tracks uploaded successfully');
          return res.json();
        } else { throw new Error('Failed to upload tracks'); }
      })
      .then(() => {
        fetch('/api/tracks')
          .then(res => res.json())
          .then(updatedTracks => {
            setTracks(updatedTracks);
          });
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
        <FaListUl size={20} />
      </button>
      <div className="app-layout" style={{ marginLeft: sidebarOpen ? 80 : 0, transition: 'margin-left 0.2s', flex: 1, overflow: 'auto', paddingBottom: 80, boxSizing: 'border-box' }}>
        {sidebarOpen && (
          <div className="side-nav" style={{ paddingTop: 80 }}>
            <button
              className={view === 'library' ? 'nav-button active' : 'nav-button'}
              onClick={() => {
                setSelectedAlbum(null);
                setSelectedArtist(null);
                setSelectedPlaylist(null);
                setView('library');
                setSidebarOpen(false);
              }}
              title="Library"
            >
              <FaMusic size={24} />
            </button>
            <button
              className={view === 'albums' ? 'nav-button active' : 'nav-button'}
              onClick={() => {
                setSelectedAlbum(null);
                setSelectedArtist(null);
                setSelectedPlaylist(null);
                setView('albums');
                setSidebarOpen(false);
              }}
              title="Albums"
            >
              <FaCompactDisc size={24} />
            </button>
            <button
              className={view === 'artists' ? 'nav-button active' : 'nav-button'}
              onClick={() => {
                setSelectedAlbum(null);
                setSelectedArtist(null);
                setSelectedPlaylist(null);
                setView('artists');
                setSidebarOpen(false);
              }}
              title="Artists"
            >
              <FaUser size={24} />
            </button>
            <button
              className={view === 'playlists' ? 'nav-button active' : 'nav-button'}
              onClick={() => {
                setSelectedAlbum(null);
                setSelectedArtist(null);
                setView('playlists');
                setSidebarOpen(false);
              }}
              title="Playlists"
            >
              <FaListUl size={24} />
            </button>
            <button
              className={view === 'settings' ? 'nav-button active' : 'nav-button'}
              onClick={() => {
                setView('settings');
                setSidebarOpen(false);
              }}
              title="Settings"
            >
              <FaCog size={24} />
            </button>
          </div>
        )}
        {/* LIBRARY VIEW */}
        {view === 'library' && (
          <div className="track-list" style={{ overflow: 'visible', maxHeight: 'none' }}>
            <h1 className="app-title">
              {selectedPlaylist
                ? `Playlist: ${selectedPlaylist.name}`
                : selectedAlbum
                  ? `Album: ${selectedAlbum.title}`
                  : selectedArtist
                    ? `Tracks by ${selectedArtist.name}`
                    : 'Your Library'}
            </h1>
            <div className="track-header">
              <div className="col-title">Title</div>
              <div className="col-artist">Artist</div>
              <div className="col-album">Album</div>
            </div>

            {(selectedPlaylist ? selectedPlaylist.tracks : tracks)
              .filter(track => {
                if (selectedAlbum) return track.album?.id === selectedAlbum.id;
                if (selectedArtist) return track.album?.artist?.id === selectedArtist.id;
                return true;
              })
              .map((track) => {
                const index = tracks.findIndex(t => t.id === track.id);
                return (
                  <div
                    key={track.id}
                    className={`track-item ${currentTrackIndex === index ? 'active' : ''}`}
                    onClick={() => playTrack(index)}
                  >
                    <div className="col-title">{track.title || track.id}</div>
                    <div className="col-artist">{track.album?.artist?.name || 'Unknown Artist'}</div>
                    <div className="col-album">{track.album?.title || 'Unknown Album'}</div>
                  </div>
                )
              })}
          </div>
        )}

        {/* PLAYLISTS VIEW */}
        {view === 'playlists' && (
          <div className="playlist-list">
            <h1 className="app-title">Playlists</h1>
            <div className="tile-grid">
              {playlists.map(playlist => (
                <div
                  key={playlist.id}
                  className="tile"
                  onClick={async () => {
                    const res = await fetch(`/api/playlists/${playlist.id}`);
                    const data = await res.json();
                    setSelectedPlaylist(data);
                    setView('library');
                  }}
                >
                  <div className="tile-title">{playlist.name}</div>
                  <div className="tile-subtitle">{playlist.tracks.length} tracks</div>
                </div>
              ))}
            </div>
            <CreatePlaylistForm tracks={tracks} onCreated={async () => {
              const res = await fetch('/api/playlists');
              const data = await res.json();
              setPlaylists(data);
            }} />
          </div>
        )}


        {/* ALBUM VIEW */}
        {view === 'albums' && (
          <div className="album-list">
            <h1 className="app-title">Albums</h1>
            <div className="tile-grid">
              {albums
                .filter(album => !selectedArtist || album.artist?.id === selectedArtist.id)
                .map(album => (
                  <div
                    key={album.id}
                    className="tile"
                    onClick={() => {
                      setSelectedAlbum(album);
                      setView('library');
                    }}
                  >
                    <div className="tile-title">{album.title}</div>
                    <div className="tile-subtitle">{album.artist?.name}</div>
                  </div>
                ))}
            </div>
          </div>
        )}

        {/* ARTIST VIEW */}
        {view === 'artists' && (
          <div className="artist-list">
            <h1 className="app-title">Artists</h1>
            <div className="tile-grid">
              {artists.map(artist => (
                <div
                  key={artist.id}
                  className="tile"
                  onClick={() => {
                    setSelectedArtist(artist);
                    setView('albums');
                  }}
                >
                  <div className="tile-title">{artist.name}</div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* SETTINGS VIEW */}
        {view === 'settings' && (
          <div className="settings">
            <h1 className="app-title">Settings</h1>
            <form className="settings-form" onSubmit={e => e.preventDefault()}>
              <div className="settings-row">
                <label htmlFor="primary-color-select" className="settings-label">Accent Color</label>
                <select
                  id="primary-color-select"
                  value={primaryColor}
                  onChange={e => setPrimaryColor(e.target.value)}
                  className="settings-select"
                >
                  <option value="#e5e743">Yellow (#e5e743)</option>
                  <option value="#1db954">Green (#1db954)</option>
                  <option value="#3fa7d6">Blue (#3fa7d6)</option>
                  <option value="#ff4f81">Pink (#ff4f81)</option>
                  <option value="#ff9800">Orange (#ff9800)</option>
                  <option value="#a259a2">Purple (#a259a2)</option>
                  <option value="#fff">White (#fff)</option>
                  <option value="#ff0000">Red (#ff0000)</option>
                </select>
              </div>
              <div className="settings-row">
                <label htmlFor="upload" className="settings-label">Upload Tracks</label>
                <div className="settings-file-group">
                  <input
                    id="upload"
                    type="file"
                    accept="audio/*"
                    onChange={handleFileUpload}
                    className="settings-file"
                  />
                </div>
              </div>
              <div className="settings-row">
                <label htmlFor="rescan" className="settings-label">Rescan Library</label>
                <button
                  id="rescan"
                  type="button"
                  className="settings-neutral-button"
                  onClick={() => {
                    fetch('/api/ingestion/scan', { method: 'POST' })
                      .then(res => {
                        if (res.ok) {
                          alert('Library rescan started');
                        } else {
                          alert('Failed to start rescan');
                        }
                      })
                      .catch(err => console.error('Failed to start rescan:', err));
                  }}
                >
                  Rescan
                </button>
              </div>
            </form>
          </div>
        )}

      </div>

      {currentTrack && (
        <footer className="player-bar" style={{ position: 'fixed', left: 0, right: 0, bottom: 0, zIndex: 101 }}>
          <audio
            ref={audioRef}
            loop={loop}
            src={`/api/tracks/${currentTrack.id}/stream`}
            onTimeUpdate={() => setCurrentTime(audioRef.current.currentTime)}
            onLoadedMetadata={() => setDuration(audioRef.current.duration)}
            onEnded={nextTrack}
          />
          {isMobile ? (
            <>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: 8, width: '100%' }}>
                <div className="title" style={{ fontWeight: 'bold', fontSize: 18, textAlign: 'center', marginBottom: 2 }}>
                  {currentTrack.title || currentTrack.id}
                </div>
                <div className="meta" style={{ fontSize: 14, color: '#888', textAlign: 'center' }}>
                  {currentTrack.album?.artist?.name || 'Unknown Artist'} — {currentTrack.album?.title || 'Unknown Album'}
                </div>
              </div>
              <div className="player-controls" style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', width: '100%' }}>
                <button className={`shuffle ${shuffle ? 'active' : ''}`} onClick={toggleShuffle}>
                  <FaRandom />
                </button>
                <button onClick={prevTrack}><FaStepBackward /></button>
                <button onClick={() => setIsPlaying(!isPlaying)} style={{ margin: '0 16px' }}>
                  {isPlaying ? <FaPause /> : <FaPlay />}
                </button>
                <button onClick={nextTrack}><FaStepForward /></button>
                <button className={`loop ${loop ? 'active' : ''}`} onClick={() => setLoop(!loop)}>
                  <FaRedo />
                </button>
              </div>
              <div className="seek-bar">
                <span className="time">{formatTime(currentTime)}</span>
                <input
                  type="range"
                  min={0}
                  max={duration || 0}
                  value={currentTime}
                  step={0.1}
                  onChange={handleSeek}
                />
                <span className="time">{formatTime(duration)}</span>
              </div>
              {/* Volume control hidden on mobile */}
            </>
          ) : (
            <>
              <div className="track-info">
                <div className="title">{currentTrack.title || currentTrack.id}</div>
                <div className="meta">
                  {currentTrack.album?.artist?.name || 'Unknown Artist'} — {currentTrack.album?.title || 'Unknown Album'}
                </div>
              </div>
              <div className="player-controls">
                <button className={`shuffle ${shuffle ? 'active' : ''}`} onClick={toggleShuffle}>
                  <FaRandom />
                </button>
                <button onClick={prevTrack}><FaStepBackward /></button>
                <button onClick={() => setIsPlaying(!isPlaying)}>
                  {isPlaying ? <FaPause /> : <FaPlay />}
                </button>
                <button onClick={nextTrack}><FaStepForward /></button>
                <button className={`loop ${loop ? 'active' : ''}`} onClick={() => setLoop(!loop)}>
                  <FaRedo />
                </button>
              </div>
              <div className="seek-bar">
                <span className="time">{formatTime(currentTime)}</span>
                <input
                  type="range"
                  min={0}
                  max={duration || 0}
                  value={currentTime}
                  step={0.1}
                  onChange={handleSeek}
                />
                <span className="time">{formatTime(duration)}</span>
              </div>
              <div className="volume-control">
                <button
                  onClick={() => setIsMuted(!isMuted)}
                  className="mute-button"
                  title={isMuted ? 'Unmute' : 'Mute'}
                >
                  {isMuted ? <FaVolumeMute /> : <FaVolumeUp />}
                </button>
                <input
                  type="range"
                  min="0"
                  max="1"
                  step="0.01"
                  value={volume}
                  onChange={(e) => setVolume(parseFloat(e.target.value))}
                />
              </div>
            </>
          )}
        </footer>
      )}
    </div>
  );
}

function CreatePlaylistForm({ tracks, onCreated }) {
  const [name, setName] = useState("");
  const [selectedTrackIds, setSelectedTrackIds] = useState([]);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const res = await fetch("/api/playlists", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, trackIds: selectedTrackIds })
      });
      if (!res.ok) throw new Error("Failed to create playlist");
      setName("");
      setSelectedTrackIds([]);
      if (onCreated) await onCreated();
    } catch (err) {
      alert("Error creating playlist");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form className="create-playlist-form" onSubmit={handleSubmit} style={{ marginTop: 32 }}>
      <h2>Create Playlist</h2>
      <input
        type="text"
        placeholder="Playlist name"
        value={name}
        onChange={e => setName(e.target.value)}
        required
        disabled={submitting}
      />
      <div className="track-checkbox-list">
        {tracks.map(track => (
          <label key={track.id} className="track-checkbox-item">
            <input
              type="checkbox"
              checked={selectedTrackIds.includes(track.id)}
              onChange={e => {
                if (e.target.checked) {
                  setSelectedTrackIds([...selectedTrackIds, track.id]);
                } else {
                  setSelectedTrackIds(selectedTrackIds.filter(id => id !== track.id));
                }
              }}
              disabled={submitting}
            />
            <span className="track-checkbox-title">{track.title || track.id}</span>
            <span className="track-checkbox-meta">{track.album?.artist?.name || "Unknown Artist"}</span>
          </label>
        ))}
      </div>
      <button type="submit" disabled={submitting || !name || selectedTrackIds.length === 0}>Create</button>
    </form>
  );
}

export default App;
