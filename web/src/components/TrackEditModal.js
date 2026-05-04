import React from 'react';

export default function TrackEditModal({ editingTrack, editForm, handleEditFormChange, saveEditTrack, editSaving, setEditingTrack }) {
  if (!editingTrack) return null;
  return (
    <div className="modal-backdrop" onClick={() => setEditingTrack(null)}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <form className="edit-form" onSubmit={e => { e.preventDefault(); saveEditTrack(); }}>
          <div className="form-row">
            <label htmlFor="edit-title">Title</label>
            <input id="edit-title" name="title" type="text" value={editForm.title} onChange={handleEditFormChange} required />
          </div>
          <div className="form-row">
            <label htmlFor="edit-album">Album</label>
            <input id="edit-album" name="album" type="text" value={editForm.album} onChange={handleEditFormChange} required />
          </div>
          <div className="form-row">
            <label htmlFor="edit-artist">Artist</label>
            <input id="edit-artist" name="artist" type="text" value={editForm.artist} onChange={handleEditFormChange} required />
          </div>
          <div className="form-actions">
            <button type="button" className="cancel" onClick={() => setEditingTrack(null)} disabled={editSaving}>Cancel</button>
            <button type="submit" disabled={editSaving || !editForm.title || !editForm.album || !editForm.artist}>{editSaving ? 'Saving...' : 'Save'}</button>
          </div>
        </form>
      </div>
    </div>
  );
}
