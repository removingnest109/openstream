import React from 'react';
import { FaUpload } from 'react-icons/fa';

export default function AlbumTile({ album, albumCoverUrl, logoSvg, albumArtUploading, handleAlbumArtUpload, setSelectedAlbum, setView }) {
  return (
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
      {!album.albumArtPath && (
        <label className="album-art-upload-btn" style={{ display: 'block', margin: '0.5rem auto 0', cursor: albumArtUploading[album.id] ? 'not-allowed' : 'pointer' }} onClick={e => e.stopPropagation()}>
          <FaUpload style={{ marginRight: 4 }} />
          {albumArtUploading[album.id] ? 'Uploading...' : 'Upload Art'}
          <input
            type="file"
            accept="image/jpeg"
            style={{ display: 'none' }}
            disabled={albumArtUploading[album.id]}
            onChange={e => {
              if (e.target.files && e.target.files[0]) {
                handleAlbumArtUpload(album.id, e.target.files[0]);
                e.target.value = '';
              }
            }}
          />
        </label>
      )}
      <div className="tile-title">{album.title}</div>
      <div className="tile-subtitle">{album.artist?.name}</div>
    </div>
  );
}
