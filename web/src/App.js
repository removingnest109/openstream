import { useEffect, useState } from 'react';
import './App.css';

function App() {
  const [tracks, setTracks] = useState([]);
  const [currentTrack, setCurrentTrack] = useState(null);

  useEffect(() => {
    fetch('/api/tracks')
      .then(res => res.json())
      .then(setTracks)
      .catch(err => console.error('Failed to load tracks:', err));
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <h1>Track Player</h1>
        {tracks.length === 0 ? (
          <p>Loading tracks...</p>
        ) : (
          <div>
            {tracks.map(track => (
              <button
                key={track.id}
                onClick={() => setCurrentTrack(track.id)}
                style={{ display: 'block', margin: '0.5rem auto' }}
              >
                ▶️ {track.title || track.id}
              </button>
            ))}
          </div>
        )}

        {currentTrack && (
          <audio
            controls
            autoPlay
            src={`/api/tracks/${currentTrack}/stream`}
            style={{ marginTop: '1rem' }}
          >
            Your browser does not support the audio element.
          </audio>
        )}
      </header>
    </div>
  );
}

export default App;
