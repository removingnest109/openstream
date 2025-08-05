import React from 'react';
import TrackItem from './TrackItem';
import { FaUpload } from 'react-icons/fa';

export default function TrackList({
  tracks,
  setTracks,
  selectedPlaylist,
  selectedAlbum,
  selectedArtist,
  isMobile,
  currentTrackIndex,
  playTrack,
  albumArtUrlMap,
  logoSvg,
  trackMenuOpen,
  setTrackMenuOpen,
  openEditTrack,
  albumArtUploading,
  handleAlbumArtUpload
}) {
  // Build filteredTracks once
  const filteredTracks = (selectedPlaylist ? selectedPlaylist.tracks : tracks)
    .filter(track => {
      if (selectedAlbum) return track.album?.id === selectedAlbum.id;
      if (selectedArtist) return track.album?.artist?.id === selectedArtist.id;
      return true;
    });

  // New: state for delete modal
  const [deletingTrack, setDeletingTrack] = React.useState(null);
  const [showDeleteModal, setShowDeleteModal] = React.useState(false);

  // Handler to open delete modal
  const openDeleteTrack = (track) => {
    setDeletingTrack(track);
    setShowDeleteModal(true);
    setTrackMenuOpen(null);
  };

  const handleDeleteTrack = async (trackId, deleteFile) => {
    try {
      const res = await fetch(`/api/tracks/${trackId}?deleteFile=${deleteFile ? 'true' : 'false'}`, {
        method: 'DELETE',
      });
      if (!res.ok) {
        const err = await res.text();
        alert('Failed to delete track: ' + err);
        return;
      }
      // Refresh tracks
      setTimeout(async () => {
        const updatedTracks = await fetch('/api/tracks').then(r => r.json());
        setShowDeleteModal(false);
        setDeletingTrack(null);
        if (updatedTracks && typeof window.setTracks !== 'function' && typeof setTracks === 'function') {
          setTracks(updatedTracks);
        } else if (updatedTracks && typeof window.setTracks === 'function') {
          window.setTracks(updatedTracks);
        }
      }, 500);
    } catch (err) {
      alert('Failed to delete track: ' + err.message);
    }
  };

  return (
    <>
      <div className="track-list" style={{ overflow: 'visible', maxHeight: 'none' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <h1 className="app-title" style={{ marginBottom: 0 }}>
            {selectedPlaylist
              ? `Playlist: ${selectedPlaylist.name}`
              : selectedAlbum
                ? `Album: ${selectedAlbum.title}`
                : selectedArtist
                  ? `Tracks by ${selectedArtist.name}`
                  : 'Your Library'}
          </h1>
          {selectedAlbum && !selectedAlbum.albumArtPath && (
            <label className="album-art-upload-btn" style={{ display: 'inline-flex', alignItems: 'center', cursor: albumArtUploading?.[selectedAlbum.id] ? 'not-allowed' : 'pointer', marginBottom: 0 }}>
              <FaUpload style={{ marginRight: 4 }} />
              {albumArtUploading?.[selectedAlbum.id] ? 'Uploading...' : 'Upload Art'}
              <input
                type="file"
                accept="image/jpeg"
                style={{ display: 'none' }}
                disabled={albumArtUploading?.[selectedAlbum.id]}
                onChange={e => {
                  if (e.target.files && e.target.files[0]) {
                    handleAlbumArtUpload(selectedAlbum.id, e.target.files[0]);
                    e.target.value = '';
                  }
                }}
              />
            </label>
          )}
        </div>
        {!isMobile && (
          <div className="track-header">
            <div className="col-art" style={{ width: 48 }}></div>
            <div className="col-title">Title</div>
            <div className="col-artist">Artist</div>
            <div className="col-album">Album</div>
          </div>
        )}
        {filteredTracks.map((track, i) => {
          const index = i;
          const artUrl = albumArtUrlMap[track.id] || logoSvg;
          const menuBtn = (
            <div
              className="track-menu-wrapper"
              style={{ position: 'relative', marginLeft: 8 }}
            >
              <button
                className="track-menu-btn"
                title="Track options"
                tabIndex={0}
                onClick={e => {
                  e.stopPropagation();
                  setTrackMenuOpen(trackMenuOpen === track.id ? null : track.id);
                }}
              >
                &#9776;
              </button>
              {trackMenuOpen === track.id && (
                <div className="track-menu-dropdown" onClick={e => e.stopPropagation()}>
                  <button className="track-menu-item" onClick={() => { setTrackMenuOpen(null); openEditTrack(track); }}>Edit</button>
                  <button className="track-menu-item" style={{ color: '#e74c3c' }} onClick={() => openDeleteTrack(track)}>Delete</button>
                </div>
              )}
            </div>
          );
          return (
            <TrackItem
              key={track.id}
              track={track}
              index={index}
              filteredTracks={filteredTracks}
              isMobile={isMobile}
              currentTrackIndex={currentTrackIndex}
              playTrack={playTrack}
              artUrl={artUrl}
              logoSvg={logoSvg}
              menuBtn={menuBtn}
            />
          );
        })}
      </div>
      {/* Delete confirmation modal */}
      {showDeleteModal && deletingTrack && (
        <div className="modal-backdrop" onClick={() => setShowDeleteModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div style={{ marginBottom: '1rem' }}>
              <h2 style={{ color: '#e74c3c', margin: 0 }}>Delete Track</h2>
              <p>Are you sure you want to delete <b>{deletingTrack.title || deletingTrack.id}</b>?</p>
              <p>This action cannot be undone.</p>
              <p>Would you like to delete the file on disk as well, or just the database entry?</p>
            </div>
            <div className="form-actions" style={{ display: 'flex', gap: '1rem' }}>
              <button
                className="track-menu-item"
                style={{ background: '#e74c3c', color: '#fff', fontWeight: 500, borderRadius: 6, padding: '0.5rem 1.25rem' }}
                onClick={() => {
                  // Call API to delete DB only
                  handleDeleteTrack(deletingTrack.id, false);
                }}
              >Delete DB Only</button>
              <button
                className="track-menu-item"
                style={{ background: '#e74c3c', color: '#fff', fontWeight: 500, borderRadius: 6, padding: '0.5rem 1.25rem' }}
                onClick={() => {
                  // Call API to delete DB and file
                  handleDeleteTrack(deletingTrack.id, true);
                }}
              >Delete DB & File</button>
              <button
                className="track-menu-item cancel"
                style={{ background: '#333', color: '#fff', borderRadius: 6, padding: '0.5rem 1.25rem' }}
                onClick={() => setShowDeleteModal(false)}
              >Cancel</button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
