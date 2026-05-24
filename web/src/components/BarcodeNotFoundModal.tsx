"use client";

import { useT } from "../i18n/context";

type BarcodeNotFoundModalProps = {
    open: boolean;
    serial: string;
    modelName?: string;
    year?: number;
    isAuthenticated: boolean;
    onAddDevice: () => void;
    onAddDeviceUnmatched: () => void;
    onScanAgain: () => void;
    onClose: () => void;
};

export function BarcodeNotFoundModal({
    open,
    serial,
    modelName,
    year,
    isAuthenticated,
    onAddDevice,
    onAddDeviceUnmatched,
    onScanAgain,
    onClose,
}: BarcodeNotFoundModalProps) {
    const t = useT();
    const s = t.scanner;

    if (!open) return null;

    return (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
            <div className="absolute inset-0 bg-black/60" onClick={onClose} />

            <div className="relative w-full max-w-md rounded-xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-xl overflow-hidden">
                <div className="px-4 py-3 border-b border-gray-200 dark:border-gray-800 flex items-center justify-between">
                    <div className="text-sm font-medium text-gray-900 dark:text-gray-100">
                        {s.notInInventory}
                    </div>
                    <button
                        type="button"
                        onClick={onClose}
                        className="text-sm text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
                    >
                        {s.close}
                    </button>
                </div>

                <div className="p-4 space-y-4">
                    <p className="text-sm text-gray-600 dark:text-gray-400 text-center">
                        {s.serialNotFound}
                    </p>

                    <div className="rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 px-4 py-3 text-center space-y-1">
                        <div className="font-mono text-sm font-semibold text-gray-900 dark:text-gray-100">
                            {serial}
                        </div>
                        {modelName ? (
                            <div className="text-xs text-gray-500 dark:text-gray-400">
                                <span>{s.identifiedAs} </span>
                                <span className="font-medium text-gray-700 dark:text-gray-300">{modelName}</span>
                            </div>
                        ) : (
                            <div className="text-xs text-gray-500 dark:text-gray-400">{s.unknownDevice}</div>
                        )}
                        {year && (
                            <div className="text-xs text-gray-400 dark:text-gray-500">
                                {s.manufacturedIn} {year}
                            </div>
                        )}
                    </div>

                    <div className="space-y-2">
                        {isAuthenticated && (
                            <button
                                type="button"
                                onClick={onAddDevice}
                                className="w-full px-3 py-2.5 rounded-lg text-sm font-medium bg-blue-600 hover:bg-blue-700 text-white transition-colors"
                            >
                                {s.addNewDevice}
                            </button>
                        )}

                        {isAuthenticated && modelName && (
                            <button
                                type="button"
                                onClick={onAddDeviceUnmatched}
                                className="w-full px-3 py-2.5 rounded-lg text-sm font-medium bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-300 transition-colors"
                            >
                                {s.notThisModel}
                            </button>
                        )}

                        <button
                            type="button"
                            onClick={onScanAgain}
                            className="w-full px-3 py-2.5 rounded-lg text-sm font-medium bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-300 transition-colors"
                        >
                            {s.scanAgain}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
