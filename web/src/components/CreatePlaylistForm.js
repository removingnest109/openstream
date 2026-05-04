import React, { useState } from 'react';

export default function CreatePlaylistForm({ tracks, onCreated }) {
  const [name, setName] = useState("");
  const [selectedTrackIds, setSelectedTrackIds] = useState([]);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await fetch('/api/playlists', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, trackIds: selectedTrackIds })
      });
      setName("");
      setSelectedTrackIds([]);
      if (onCreated) await onCreated();
    } catch (err) {
      alert('Failed to create playlist: ' + err.message);
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
                  setSelectedTrackIds(ids => [...ids, track.id]);
                } else {
                  setSelectedTrackIds(ids => ids.filter(id => id !== track.id));
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
