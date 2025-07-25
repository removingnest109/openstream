import { useEffect, useRef, useState } from 'react';
import { FaPlay, FaPause, FaStepForward, FaStepBackward, FaRandom, FaRedo, FaVolumeUp, FaVolumeMute } from 'react-icons/fa';
import './App.css';

function App() {
  const [tracks, setTracks] = useState([]);
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
  const [view, setView] = useState('library'); // 'library' | 'albums' | 'artists'
  const [selectedAlbum, setSelectedAlbum] = useState(null);
  const [selectedArtist, setSelectedArtist] = useState(null);

  const audioRef = useRef(null);
  const shuffleHistory = useRef([]);

  useEffect(() => {
    fetch('/api/tracks')
      .then(res => res.json())
      .then(setTracks)
      .catch(err => console.error('Failed to load tracks:', err));
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
    shuffleHistory.current = []; // reset history on toggle
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
        } else {        throw new Error('Failed to upload tracks'); }
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
    <div className="app-container">
      <div className="app-layout">
        <div className="side-nav">
          <h2 className="nav-title">Browse</h2>
          <button
            className={view === 'library' ? 'nav-button active' : 'nav-button'}
            onClick={() => {
              setSelectedAlbum(null);
              setSelectedArtist(null);
              setView('library');
            }}
          >
            Library
          </button>
          <button
            className={view === 'albums' ? 'nav-button active' : 'nav-button'}
            onClick={() => {
              setSelectedAlbum(null);
              setSelectedArtist(null);
              setView('albums');
            }}
          >
            Albums
          </button>
          <button
            className={view === 'artists' ? 'nav-button active' : 'nav-button'}
            onClick={() => {
              setSelectedAlbum(null);
              setSelectedArtist(null);
              setView('artists');
            }}
          >
            Artists
          </button>
          <button
            className={view === 'settings' ? 'nav-button active' : 'nav-button'}
            onClick={() => {
              setView('settings');
            }}
          >
            Settings
          </button>
        </div>

        {/* LIBRARY VIEW */}
        {view === 'library' && (
          <div className="track-list">
            <h1 className="app-title">
              {selectedAlbum
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

            {tracks
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
            <div className="setting-item">
              <label htmlFor ="rescan">Rescan Library</label>
              <button
                id="rescan"
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
            <div className="setting-item">
              <label htmlFor="upload">Upload Tracks</label>
              <input
                id="upload"
                type="file"
                accept="audio/*"
                onChange={handleFileUpload}
              />
            </div>
          </div>
        )}

      </div>

      <footer className="player-bar">
        {currentTrack ? (
          <>
            <audio
              ref={audioRef}
              loop={loop}
              src={`/api/tracks/${currentTrack.id}/stream`}
              onTimeUpdate={() => setCurrentTime(audioRef.current.currentTime)}
              onLoadedMetadata={() => setDuration(audioRef.current.duration)}
              onEnded={nextTrack}
            />

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
        ) : (
          <div className="player-placeholder">Select a track to play</div>
        )}
      </footer>
    </div>
  );
}

export default App;
