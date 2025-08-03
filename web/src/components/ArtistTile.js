import React from 'react';

export default function ArtistTile({ artist, albums, albumCoverUrlMap, logoSvg, setSelectedArtist, setView }) {
  const artistAlbums = albums.filter(album => album.artist?.id === artist.id);
  const firstAlbum = artistAlbums[0];
  const coverUrl = firstAlbum ? (albumCoverUrlMap[firstAlbum.id] || logoSvg) : logoSvg;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div
        key={artist.id}
        className="tile"
        onClick={() => {
          setSelectedArtist(artist);
          setView('albums');
        }}
      >
        <div className="album-art-wrapper album-tile-art" style={{ marginBottom: 8 }}>
          <img
            src={coverUrl}
            alt="Album Art"
            className="album-art-img"
            onError={e => { e.target.onerror = null; e.target.src = logoSvg; }}
          />
        </div>
      </div>
      <div className="tile-title">{artist.name}</div>
    </div>
  );
}
