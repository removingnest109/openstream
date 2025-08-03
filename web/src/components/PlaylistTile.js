import React from 'react';

export default function PlaylistTile({ playlist, setSelectedPlaylist, setView }) {
  return (
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
  );
}
