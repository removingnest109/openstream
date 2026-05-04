import React from 'react';
import ArtistTile from './ArtistTile';

export default function ArtistList({ artists, albums, albumCoverUrlMap, logoSvg, setSelectedArtist, setView }) {
  return (
    <div className="artist-list">
      <h1 className="app-title">Artists</h1>
      <div className="tile-grid">
        {artists.map(artist => (
          <ArtistTile
            key={artist.id}
            artist={artist}
            albums={albums}
            albumCoverUrlMap={albumCoverUrlMap}
            logoSvg={logoSvg}
            setSelectedArtist={setSelectedArtist}
            setView={setView}
          />
        ))}
      </div>
    </div>
  );
}
