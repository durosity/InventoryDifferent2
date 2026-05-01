'use client';

import { useState, useCallback } from 'react';

export interface SlideshowSettings {
  duration: number;
  favoritesOnly: boolean;
  order: 'random' | 'year';
  showHistoricalNotes: boolean;
  showProgressBar: boolean;
  statusFilter: string[];
}

const DEFAULTS: SlideshowSettings = {
  duration: 8,
  favoritesOnly: false,
  order: 'random',
  showHistoricalNotes: true,
  showProgressBar: true,
  statusFilter: ['COLLECTION'],
};

const STORAGE_KEY = 'slideshow_settings';

export function useSlideshowSettings() {
  const [settings, setSettings] = useState<SlideshowSettings>(() => {
    if (typeof window === 'undefined') return DEFAULTS;
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      return stored ? { ...DEFAULTS, ...JSON.parse(stored) } : DEFAULTS;
    } catch {
      return DEFAULTS;
    }
  });

  const update = useCallback((patch: Partial<SlideshowSettings>) => {
    setSettings(prev => {
      const next = { ...prev, ...patch };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      return next;
    });
  }, []);

  return { settings, update };
}
