export default function TrackItem({
  track,
  filteredTracks,
  isMobile,
  currentTrackId,
  playTrack,
  artUrl,
  logoSvg,
  menuBtn
}) {
  if (isMobile) {
    return (
      <div
        key={track.id}
        className={`track-item mobile ${currentTrackId === track.id ? 'active' : ''}`}
        onClick={() => playTrack(track.id, filteredTracks)}
        style={{ display: 'flex', alignItems: 'center', padding: '8px 0', borderBottom: '1px solid #ccc' }}
      >
        <div className="album-art-wrapper" style={{ width: 48, height: 48, marginRight: 12 }}>
          <img
            src={artUrl}
            alt="Album Art"
            className="album-art-img"
            style={{ width: 48, height: 48, objectFit: 'cover', borderRadius: 6 }}
            onError={e => { e.target.onerror = null; e.target.src = logoSvg; }}
          />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minWidth: 0 }}>
          <span style={{ fontWeight: 500, fontSize: 16, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{track.title || track.id}</span>
          <span style={{ fontSize: 13, color: '#888', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{track.album?.artist?.name || 'Unknown Artist'}</span>
        </div>
        {menuBtn}
      </div>
    );
  } else {
    return (
      <div
        key={track.id}
        className={`track-item ${currentTrackId === track.id ? 'active' : ''}`}
        onClick={() => playTrack(track.id, filteredTracks)}
      >
        <div className="album-art-wrapper">
          <img
            src={artUrl}
            alt="Album Art"
            className="album-art-img"
            onError={e => { e.target.onerror = null; e.target.src = logoSvg; }}
          />
        </div>
        <div className="col-title">{track.title || track.id}</div>
        <div className="col-artist">{track.album?.artist?.name || 'Unknown Artist'}</div>
        <div className="col-album">{track.album?.title || 'Unknown Album'}</div>
        {menuBtn}
      </div>
    );
  }
}
