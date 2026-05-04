import React from 'react';
import PlaylistTile from './PlaylistTile';
import CreatePlaylistForm from './CreatePlaylistForm';

export default function PlaylistList({ playlists, tracks, setSelectedPlaylist, setView, setPlaylists }) {
  return (
    <div className="playlist-list">
      <h1 className="app-title">Playlists</h1>
      <div className="tile-grid">
        {playlists.map(playlist => (
          <PlaylistTile
            key={playlist.id}
            playlist={playlist}
            setSelectedPlaylist={setSelectedPlaylist}
            setView={setView}
          />
        ))}
      </div>
      <CreatePlaylistForm tracks={tracks} onCreated={async () => {
        const res = await fetch('/api/playlists');
        const data = await res.json();
        setPlaylists(data);
      }} />
    </div>
  );
}
