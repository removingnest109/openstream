import React from 'react';

export default function SettingsForm({ primaryColor, setPrimaryColor, handleFileUpload, handleRescan }) {
  return (
    <form className="settings-form" onSubmit={e => e.preventDefault()}>
      <div className="settings-row">
        <label htmlFor="primary-color-select" className="settings-label">Accent Color</label>
        <select
          id="primary-color-select"
          value={primaryColor}
          onChange={e => setPrimaryColor(e.target.value)}
          className="settings-select"
        >
          <option value="#e5e743">Yellow (#e5e743)</option>
          <option value="#1db954">Green (#1db954)</option>
          <option value="#3fa7d6">Blue (#3fa7d6)</option>
          <option value="#ff4f81">Pink (#ff4f81)</option>
          <option value="#ff9800">Orange (#ff9800)</option>
          <option value="#a259a2">Purple (#a259a2)</option>
          <option value="#fff">White (#fff)</option>
          <option value="#ff0000">Red (#ff0000)</option>
        </select>
      </div>
      <div className="settings-row">
        <label htmlFor="upload" className="settings-label">Upload Tracks</label>
        <div className="settings-file-group">
          <input
            id="upload"
            type="file"
            accept="audio/*"
            onChange={handleFileUpload}
            className="settings-file"
          />
        </div>
      </div>
      <div className="settings-row">
        <label htmlFor="rescan" className="settings-label">Rescan Library</label>
        <button
          id="rescan"
          type="button"
          className="settings-neutral-button"
          onClick={handleRescan}
        >
          Rescan
        </button>
      </div>
    </form>
  );
}
