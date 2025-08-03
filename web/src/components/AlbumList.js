import React from 'react';
import AlbumTile from './AlbumTile';

export default function AlbumList({ albums, selectedArtist, albumCoverUrlMap, logoSvg, albumArtUploading, handleAlbumArtUpload, setSelectedAlbum, setView }) {
  return (
    <div className="album-list">
      <h1 className="app-title">Albums</h1>
      <div className="tile-grid">
        {albums
          .filter(album => !selectedArtist || album.artist?.id === selectedArtist.id)
          .map(album => (
            <AlbumTile
              key={album.id}
              album={album}
              albumCoverUrl={albumCoverUrlMap[album.id]}
              logoSvg={logoSvg}
              albumArtUploading={albumArtUploading}
              handleAlbumArtUpload={handleAlbumArtUpload}
              setSelectedAlbum={setSelectedAlbum}
              setView={setView}
            />
          ))}
      </div>
    </div>
  );
}
