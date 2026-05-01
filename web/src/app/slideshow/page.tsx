'use client';

import { useEffect, useRef, useState } from 'react';
import { useQuery, useLazyQuery } from '@apollo/client';
import gql from 'graphql-tag';
import Link from 'next/link';
import { useT } from '../../i18n/context';
import { API_BASE_URL } from '../../lib/config';
import { useSlideshowSettings } from './hooks/useSlideshowSettings';
import { useSlideshow, SlideDevice } from './hooks/useSlideshow';
import { SlideView } from './_components/SlideView';
import { SettingsDrawer } from './_components/SettingsDrawer';
import { ProgressBar } from './_components/ProgressBar';

const GET_DEVICES = gql`
  query SlideshowGetDevices {
    devices {
      id
      name
      additionalName
      releaseYear
      isFavorite
      status
      category { name }
      images {
        id
        path
        thumbnailPath
        isThumbnail
        thumbnailMode
      }
    }
  }
`;

const GET_DEVICE_NOTES = gql`
  query SlideshowGetDeviceNotes($where: DeviceWhereInput!) {
    device(where: $where) {
      id
      historicalNotes
    }
  }
`;

export default function SlideshowPage() {
  const t = useT();
  const ts = t.pages.slideshow;

  const { settings, update } = useSlideshowSettings();
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [controlsVisible, setControlsVisible] = useState(true);
  const controlsTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const { data, loading } = useQuery(GET_DEVICES);
  const allDevices: SlideDevice[] = data?.devices ?? [];

  const { slides, currentIndex, paused, next, prev, togglePause } = useSlideshow(allDevices, settings);

  // Historical notes: cache by deviceId
  const notesCache = useRef<Record<string, string | null>>({});
  const [, setNotesVersion] = useState(0);
  const [fetchNotes] = useLazyQuery(GET_DEVICE_NOTES);

  // Lazy-fetch notes for current and next slide
  useEffect(() => {
    if (!settings.showHistoricalNotes || slides.length === 0) return;
    const ids = [
      slides[currentIndex]?.id,
      slides[(currentIndex + 1) % slides.length]?.id,
    ].filter((id): id is string => !!id && !(id in notesCache.current));

    ids.forEach(id => {
      fetchNotes({ variables: { where: { id } } }).then(({ data: d }) => {
        notesCache.current[id] = d?.device?.historicalNotes ?? null;
        setNotesVersion(v => v + 1);
      });
    });
  }, [currentIndex, slides, settings.showHistoricalNotes, fetchNotes]);

  const currentDevice = slides[currentIndex];
  const currentNotes = currentDevice ? (notesCache.current[currentDevice.id] ?? undefined) : undefined;

  // Show controls on mouse move, hide after 3s
  const handleMouseMove = () => {
    setControlsVisible(true);
    if (controlsTimerRef.current) clearTimeout(controlsTimerRef.current);
    controlsTimerRef.current = setTimeout(() => setControlsVisible(false), 3000);
  };

  useEffect(() => {
    return () => { if (controlsTimerRef.current) clearTimeout(controlsTimerRef.current); };
  }, []);

  if (loading) {
    return (
      <div className="fixed inset-0 bg-black flex items-center justify-center z-50">
        <div className="text-white/40 text-sm tracking-widest uppercase">Loading…</div>
      </div>
    );
  }

  return (
    <div
      className="fixed inset-0 bg-black overflow-hidden z-50"
      style={{ cursor: controlsVisible ? 'default' : 'none' }}
      onMouseMove={handleMouseMove}
    >
      {/* Current slide */}
      {currentDevice && (
        <SlideView
          key={currentIndex}
          device={currentDevice}
          historicalNotes={currentNotes}
          showHistoricalNotes={settings.showHistoricalNotes}
          slideIndex={currentIndex}
          apiBaseUrl={API_BASE_URL}
          duration={settings.duration}
        />
      )}

      {/* Empty states */}
      {slides.length === 0 && !loading && (
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="text-center">
            {settings.favoritesOnly ? (
              <>
                <span className="material-symbols-outlined text-white/20 block mb-4" style={{ fontSize: '80px' }}>star</span>
                <p className="text-white/60 text-lg mb-2">{ts.noFavorites}</p>
                <p className="text-white/35 text-sm">{ts.noFavoritesHint}</p>
              </>
            ) : (
              <>
                <span className="material-symbols-outlined text-white/20 block mb-4" style={{ fontSize: '80px' }}>devices</span>
                <p className="text-white/60 text-lg">{ts.noDevices}</p>
              </>
            )}
          </div>
        </div>
      )}

      {/* Progress bar */}
      {currentDevice && settings.showProgressBar && (
        <ProgressBar duration={settings.duration} paused={paused} slideKey={currentIndex} />
      )}

      {/* Top controls — fade in on mouse move */}
      <div
        className="absolute top-0 left-0 right-0 flex items-center justify-between px-6 py-5 transition-opacity duration-200"
        style={{
          opacity: controlsVisible || settingsOpen ? 1 : 0,
          background: 'linear-gradient(to bottom, rgba(0,0,0,0.5), transparent)',
        }}
      >
        {/* Wordmark */}
        <div className="flex items-center gap-2">
          <div
            className="w-1.5 h-1.5 rounded-full"
            style={{ background: 'linear-gradient(135deg, #5EBD3E, #009CDF)' }}
          />
          <span className="text-[11px] text-white/45 tracking-widest uppercase font-medium">
            InventoryDifferent
          </span>
        </div>

        {/* Playback + settings buttons */}
        <div className="flex items-center gap-3">
          <Link
            href="/"
            className="w-8 h-8 rounded-full flex items-center justify-center text-white/70 hover:text-white transition-colors"
            style={{ background: 'rgba(255,255,255,0.1)', backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.12)' }}
          >
            <span className="material-symbols-outlined" style={{ fontSize: '14px' }}>home</span>
          </Link>
          <button
            onClick={prev}
            className="w-8 h-8 rounded-full flex items-center justify-center text-white/70 hover:text-white transition-colors"
            style={{ background: 'rgba(255,255,255,0.1)', backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.12)' }}
          >
            <span className="material-symbols-outlined" style={{ fontSize: '14px' }}>skip_previous</span>
          </button>
          <button
            onClick={togglePause}
            className="w-8 h-8 rounded-full flex items-center justify-center text-white/70 hover:text-white transition-colors"
            style={{ background: 'rgba(255,255,255,0.1)', backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.12)' }}
          >
            <span className="material-symbols-outlined" style={{ fontSize: '14px' }}>{paused ? 'play_arrow' : 'pause'}</span>
          </button>
          <button
            onClick={next}
            className="w-8 h-8 rounded-full flex items-center justify-center text-white/70 hover:text-white transition-colors"
            style={{ background: 'rgba(255,255,255,0.1)', backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.12)' }}
          >
            <span className="material-symbols-outlined" style={{ fontSize: '14px' }}>skip_next</span>
          </button>
          <button
            onClick={() => setSettingsOpen(o => !o)}
            className="w-8 h-8 rounded-full flex items-center justify-center transition-colors text-white/70 hover:text-white"
            style={{
              background: settingsOpen ? 'rgba(0,88,188,0.6)' : 'rgba(255,255,255,0.1)',
              backdropFilter: 'blur(8px)',
              border: '1px solid rgba(255,255,255,0.12)',
            }}
          >
            <span className="material-symbols-outlined" style={{ fontSize: '14px' }}>settings</span>
          </button>
        </div>
      </div>

      {/* Settings drawer */}
      {settingsOpen && (
        <SettingsDrawer
          settings={settings}
          onUpdate={update}
          onClose={() => setSettingsOpen(false)}
        />
      )}
    </div>
  );
}
