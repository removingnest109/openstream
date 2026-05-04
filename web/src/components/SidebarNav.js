import React from 'react';
import { FaMusic, FaCompactDisc, FaUser, FaListUl, FaCog } from 'react-icons/fa';

export default function SidebarNav({ view, setView, setSelectedAlbum, setSelectedArtist, setSelectedPlaylist, sidebarOpen, setSidebarOpen }) {
  return (
    <div className="side-nav" style={{ paddingTop: 80 }}>
      <button
        className={view === 'library' ? 'nav-button active' : 'nav-button'}
        onClick={() => {
          setSelectedAlbum(null);
          setSelectedArtist(null);
          setSelectedPlaylist(null);
          setView('library');
          setSidebarOpen(false);
        }}
        title="Library"
      >
        <FaMusic size={24} />
      </button>
      <button
        className={view === 'albums' ? 'nav-button active' : 'nav-button'}
        onClick={() => {
          setSelectedAlbum(null);
          setSelectedArtist(null);
          setSelectedPlaylist(null);
          setView('albums');
          setSidebarOpen(false);
        }}
        title="Albums"
      >
        <FaCompactDisc size={24} />
      </button>
      <button
        className={view === 'artists' ? 'nav-button active' : 'nav-button'}
        onClick={() => {
          setSelectedAlbum(null);
          setSelectedArtist(null);
          setSelectedPlaylist(null);
          setView('artists');
          setSidebarOpen(false);
        }}
        title="Artists"
      >
        <FaUser size={24} />
      </button>
      <button
        className={view === 'playlists' ? 'nav-button active' : 'nav-button'}
        onClick={() => {
          setSelectedAlbum(null);
          setSelectedArtist(null);
          setView('playlists');
          setSidebarOpen(false);
        }}
        title="Playlists"
      >
        <FaListUl size={24} />
      </button>
      <button
        className={view === 'settings' ? 'nav-button active' : 'nav-button'}
        onClick={() => {
          setView('settings');
          setSidebarOpen(false);
        }}
        title="Settings"
      >
        <FaCog size={24} />
      </button>
    </div>
  );
}
