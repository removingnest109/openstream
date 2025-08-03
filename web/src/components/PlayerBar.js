import React from 'react';
import { FaRandom, FaStepBackward, FaPause, FaPlay, FaStepForward, FaRedo, FaVolumeMute, FaVolumeUp } from 'react-icons/fa';

export default function PlayerBar({
  currentTrack,
  isMobile,
  audioRef,
  loop,
  shuffle,
  isPlaying,
  currentTime,
  duration,
  volume,
  isMuted,
  formatTime,
  toggleShuffle,
  prevTrack,
  nextTrack,
  setIsPlaying,
  setLoop,
  setIsMuted,
  setVolume,
  handleSeek,
  setCurrentTime,
  setDuration
}) {
  if (!currentTrack) return null;
  return (
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
  );
}
