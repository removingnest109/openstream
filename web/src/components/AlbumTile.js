import React from 'react';
// import { FaUpload } from 'react-icons/fa';

export default function AlbumTile({ album, albumCoverUrl, logoSvg, albumArtUploading, handleAlbumArtUpload, setSelectedAlbum, setView }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div
        key={album.id}
        className="tile"
        onClick={() => {
          setSelectedAlbum(album);
          setView('library');
        }}
      >
        <div className="album-art-wrapper album-tile-art">
          <img
            src={albumCoverUrl || logoSvg}
            alt="Album Art"
            className="album-art-img"
            onError={e => { e.target.onerror = null; e.target.src = logoSvg; }}
          />
        </div>
        {/* Upload button removed, will be added to album tracks view */}
      </div>
      <div className="tile-title">{album.title}</div>
      <div className="tile-subtitle">{album.artist?.name}</div>
    </div>
  );
}
