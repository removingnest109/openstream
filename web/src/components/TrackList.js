import React from 'react';
import TrackItem from './TrackItem';

export default function TrackList({
  tracks,
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
  openEditTrack
}) {
  return (
    <div className="track-list" style={{ overflow: 'visible', maxHeight: 'none' }}>
      <h1 className="app-title">
        {selectedPlaylist
          ? `Playlist: ${selectedPlaylist.name}`
          : selectedAlbum
            ? `Album: ${selectedAlbum.title}`
            : selectedArtist
              ? `Tracks by ${selectedArtist.name}`
              : 'Your Library'}
      </h1>
      {!isMobile && (
        <div className="track-header">
          <div className="col-art" style={{ width: 48 }}></div>
          <div className="col-title">Title</div>
          <div className="col-artist">Artist</div>
          <div className="col-album">Album</div>
        </div>
      )}
      {(selectedPlaylist ? selectedPlaylist.tracks : tracks)
        .filter(track => {
          if (selectedAlbum) return track.album?.id === selectedAlbum.id;
          if (selectedArtist) return track.album?.artist?.id === selectedArtist.id;
          return true;
        })
        .map((track) => {
          const index = tracks.findIndex(t => t.id === track.id);
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
                </div>
              )}
            </div>
          );
          return (
            <TrackItem
              key={track.id}
              track={track}
              index={index}
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
  );
}
