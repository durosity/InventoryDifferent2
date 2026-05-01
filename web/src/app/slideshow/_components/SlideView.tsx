'use client';

import { useEffect, useState } from 'react';
import { SlideDevice } from '../hooks/useSlideshow';
import { pickThumbnail } from '../../../lib/pickThumbnail';

// 4 Ken Burns transform pairs cycled by slideIndex % 4
const KEN_BURNS = [
  { from: 'scale(1.06) translate(2%, 1%)',   to: 'scale(1.0) translate(-1%, -0.5%)' },
  { from: 'scale(1.06) translate(-2%, -1%)', to: 'scale(1.0) translate(1%, 0.5%)'  },
  { from: 'scale(1.06) translate(-2%, 1%)',  to: 'scale(1.0) translate(1%, -0.5%)' },
  { from: 'scale(1.06) translate(2%, -1%)',  to: 'scale(1.0) translate(-1%, 0.5%)' },
];

interface SlideViewProps {
  device: SlideDevice;
  historicalNotes: string | null | undefined;
  showHistoricalNotes: boolean;
  slideIndex: number;
  apiBaseUrl: string;
  duration: number;
}

export function SlideView({ device, historicalNotes, showHistoricalNotes, slideIndex, apiBaseUrl, duration }: SlideViewProps) {
  const [notesVisible, setNotesVisible] = useState(false);
  const kb = KEN_BURNS[slideIndex % 4];
  const animName = `kb${slideIndex % 4}`;

  useEffect(() => {
    setNotesVisible(false);
    if (!showHistoricalNotes) return;
    const id = setTimeout(() => setNotesVisible(true), 3000);
    return () => clearTimeout(id);
  }, [slideIndex, showHistoricalNotes]);

  const thumb = pickThumbnail(device.images, true);
  const imgSrc = thumb ? `${apiBaseUrl}${thumb.thumbnailPath ?? thumb.path}` : null;

  return (
    <div className="absolute inset-0" style={{ animation: 'slideFadeIn 600ms ease-out' }}>
      <style>{`
        @keyframes slideFadeIn { from { opacity: 0; } to { opacity: 1; } }
        @keyframes ${animName} {
          from { transform: ${kb.from}; }
          to   { transform: ${kb.to}; }
        }
      `}</style>

      {/* Image layer with Ken Burns */}
      <div
        className="absolute inset-[-5%] w-[110%] h-[110%]"
        style={{ animation: `${animName} ${duration}s ease-in-out forwards` }}
      >
        {imgSrc ? (
          <img src={imgSrc} alt={device.name} className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full bg-[#0d1b2a] flex items-center justify-center">
            <span className="material-symbols-outlined text-white/10" style={{ fontSize: '120px' }}>
              devices
            </span>
          </div>
        )}
      </div>

      {/* Dark gradient overlay */}
      <div
        className="absolute inset-0"
        style={{ background: 'linear-gradient(to top, rgba(0,0,0,0.88) 0%, rgba(0,0,0,0.45) 30%, rgba(0,0,0,0.08) 65%, rgba(0,0,0,0.18) 100%)' }}
      />

      {/* Bottom info bar */}
      <div className="absolute bottom-12 left-12 right-12 flex gap-12 items-end">

        {/* Left: rainbow stripe + identity text */}
        <div className="flex flex-row items-stretch gap-4 shrink-0">
          <div
            className="w-[3px] rounded-full flex-shrink-0"
            style={{
              background: 'linear-gradient(to bottom, #5EBD3E, #FFB900, #F78200, #E23838, #973999, #009CDF)',
              opacity: 0.9,
            }}
          />
          <div className="flex flex-col justify-end">
            <div className="flex items-center gap-2.5 mb-2">
              {device.category && (
                <span className="text-[11px] font-semibold tracking-[0.1em] uppercase text-white/55">
                  {device.category.name}
                </span>
              )}
              {device.category && device.releaseYear && (
                <div className="w-[3px] h-[3px] rounded-full bg-white/30" />
              )}
              {device.releaseYear && (
                <span className="text-[11px] font-semibold tracking-[0.1em] uppercase text-white/55">
                  {device.releaseYear}
                </span>
              )}
            </div>
            <div className="text-[clamp(1.75rem,3.5vw,3rem)] font-extralight tracking-tight leading-tight text-white mb-1.5 whitespace-nowrap">
              {device.name}
            </div>
            {device.additionalName && (
              <div className="text-[clamp(0.8rem,1.2vw,1rem)] text-white/45">
                {device.additionalName}
              </div>
            )}
          </div>
        </div>

        {/* Right: historical notes — always in layout, opacity-transitions in */}
        <div
          className="flex-1 border-l border-white/15 pl-6 transition-opacity duration-700 ease-in"
          style={{ opacity: notesVisible && historicalNotes ? 1 : 0 }}
        >
          <p className="text-[13px] leading-relaxed text-white/65 max-w-[480px]">
            {historicalNotes ?? ''}
          </p>
        </div>
      </div>
    </div>
  );
}
