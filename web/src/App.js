import { useEffect, useRef, useState } from 'react';
import { FaPlay, FaPause, FaStepForward, FaStepBackward, FaRandom , FaRedo, FaVolumeUp, FaVolumeMute } from 'react-icons/fa';
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

  const audioRef = useRef(null);
  const shuffleHistory = useRef([]);

  useEffect(() => {
    fetch('/api/tracks')
      .then(res => res.json())
      .then(setTracks)
      .catch(err => console.error('Failed to load tracks:', err));
  }, []);

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

  const formatTime = (t) => {
    const m = Math.floor(t / 60).toString().padStart(1, '0');
    const s = Math.floor(t % 60).toString().padStart(2, '0');
    return `${m}:${s}`;
  };

  const currentTrack = tracks[currentTrackIndex];

  return (
    <div className="app-container">
      <div className="track-list">
        <h1 className="app-title">Your Library</h1>
        <div className="track-header">
          <div className="col-title">Title</div>
          <div className="col-artist">Artist</div>
          <div className="col-album">Album</div>
        </div>
        {tracks.map((track, i) => (
          <div
            key={track.id}
            className={`track-item ${currentTrackIndex === i ? 'active' : ''}`}
            onClick={() => playTrack(i)}
          >
            <div className="col-title">{track.title || track.id}</div>
            <div className="col-artist">{track.album?.artist?.name || 'Unknown Artist'}</div>
            <div className="col-album">{track.album?.title || 'Unknown Album'}</div>
          </div>
        ))}
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
