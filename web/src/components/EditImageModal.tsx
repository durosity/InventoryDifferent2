"use client";

import { useMutation } from "@apollo/client";
import gql from "graphql-tag";
import { useState, useRef, useCallback, useEffect } from "react";
import ReactCrop, { type PercentCrop } from "react-image-crop";
import "react-image-crop/dist/ReactCrop.css";
import { RotateCcw, RotateCw, X } from "lucide-react";
import { API_BASE_URL } from "../lib/config";
import { useT } from "../i18n/context";

const EDIT_IMAGE = gql`
  mutation EditImage(
    $id: Int!, $rotation: Int!,
    $cropLeft: Float, $cropTop: Float, $cropWidth: Float, $cropHeight: Float
  ) {
    editImage(id: $id, rotation: $rotation, cropLeft: $cropLeft, cropTop: $cropTop, cropWidth: $cropWidth, cropHeight: $cropHeight) {
      id path thumbnailPath originalPath rotation cropLeft cropTop cropWidth cropHeight
    }
  }
`;

const RESET_IMAGE_EDITS = gql`
  mutation ResetImageEdits($id: Int!) {
    resetImageEdits(id: $id) {
      id path thumbnailPath originalPath rotation cropLeft cropTop cropWidth cropHeight
    }
  }
`;

export interface EditableImage {
  id: number;
  path: string;
  originalPath?: string | null;
  rotation?: number | null;
  cropLeft?: number | null;
  cropTop?: number | null;
  cropWidth?: number | null;
  cropHeight?: number | null;
}

interface Props {
  image: EditableImage;
  onClose: () => void;
  onSaved: () => void;
}

export function EditImageModal({ image, onClose, onSaved }: Props) {
  const t = useT();

  // Always edit from the original (untouched) source image
  const sourceUrl = `${API_BASE_URL}${image.originalPath ?? image.path}`;

  const [rotation, setRotation] = useState<number>(image.rotation ?? 0);
  const [shiftHeld, setShiftHeld] = useState(false);
  const [crop, setCrop] = useState<PercentCrop | undefined>(
    image.cropLeft != null && image.cropWidth != null
      ? {
          unit: "%",
          x: (image.cropLeft ?? 0) * 100,
          y: (image.cropTop ?? 0) * 100,
          width: (image.cropWidth ?? 1) * 100,
          height: (image.cropHeight ?? 1) * 100,
        }
      : undefined
  );

  // previewUrl is a canvas-rotated version of the source used in the crop editor.
  // Using canvas rotation (not CSS) ensures crop handle coordinates stay correct
  // when width/height swap at 90°/270°.
  const [previewUrl, setPreviewUrl] = useState<string>(sourceUrl);
  const hiddenImgRef = useRef<HTMLImageElement>(null);

  const generatePreview = useCallback(
    (deg: number) => {
      const img = hiddenImgRef.current;
      if (!img || !img.complete || img.naturalWidth === 0) return;
      if (deg === 0) {
        setPreviewUrl(sourceUrl);
        return;
      }
      const swap = deg === 90 || deg === 270;
      const canvas = document.createElement("canvas");
      canvas.width = swap ? img.naturalHeight : img.naturalWidth;
      canvas.height = swap ? img.naturalWidth : img.naturalHeight;
      const ctx = canvas.getContext("2d")!;
      ctx.translate(canvas.width / 2, canvas.height / 2);
      ctx.rotate((deg * Math.PI) / 180);
      ctx.drawImage(img, -img.naturalWidth / 2, -img.naturalHeight / 2);
      setPreviewUrl(canvas.toDataURL());
    },
    [sourceUrl]
  );

  useEffect(() => {
    generatePreview(rotation);
  }, [rotation, generatePreview]);

  useEffect(() => {
    const down = (e: KeyboardEvent) => { if (e.key === "Shift") setShiftHeld(true); };
    const up   = (e: KeyboardEvent) => { if (e.key === "Shift") setShiftHeld(false); };
    window.addEventListener("keydown", down);
    window.addEventListener("keyup",   up);
    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); };
  }, []);

  const handleRotate = (delta: number) => {
    const next = (rotation + delta + 360) % 360;
    setRotation(next);
    setCrop(undefined); // crop coords are in the rotated space; reset on rotation change
  };

  const [editImage, { loading: saving }] = useMutation(EDIT_IMAGE);
  const [resetImageEdits, { loading: resetting }] = useMutation(RESET_IMAGE_EDITS);

  const handleSave = async () => {
    const hasCrop = crop && crop.width > 0 && crop.height > 0;
    await editImage({
      variables: {
        id: image.id,
        rotation,
        cropLeft: hasCrop ? crop!.x / 100 : null,
        cropTop: hasCrop ? crop!.y / 100 : null,
        cropWidth: hasCrop ? crop!.width / 100 : null,
        cropHeight: hasCrop ? crop!.height / 100 : null,
      },
    });
    onSaved();
    onClose();
  };

  const handleReset = async () => {
    await resetImageEdits({ variables: { id: image.id } });
    onSaved();
    onClose();
  };

  const busy = saving || resetting;
  const isEdited = !!image.originalPath;

  return (
    <div
      className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      {/* Hidden reference image — loaded once for canvas rotation */}
      <img
        ref={hiddenImgRef}
        src={sourceUrl}
        alt=""
        style={{ display: "none" }}
        onLoad={() => generatePreview(rotation)}
      />

      <div className="bg-white dark:bg-gray-900 rounded-xl w-full max-w-2xl flex flex-col gap-4 p-6 max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold dark:text-white">
            {t.detail.editPhotoTitle}
          </h2>
          <button
            onClick={onClose}
            disabled={busy}
            className="p-1 rounded text-gray-400 hover:text-gray-600 dark:hover:text-gray-200"
          >
            <X size={20} />
          </button>
        </div>

        {/* Rotate controls */}
        <div className="flex items-center gap-2">
          <button
            onClick={() => handleRotate(270)}
            disabled={busy}
            className="flex items-center gap-1.5 px-3 py-2 text-sm bg-gray-100 dark:bg-gray-800 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 disabled:opacity-50"
          >
            <RotateCcw size={15} />
            {t.detail.rotateLeft}
          </button>
          <button
            onClick={() => handleRotate(90)}
            disabled={busy}
            className="flex items-center gap-1.5 px-3 py-2 text-sm bg-gray-100 dark:bg-gray-800 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 disabled:opacity-50"
          >
            <RotateCw size={15} />
            {t.detail.rotateRight}
          </button>
          <span className="ml-auto text-sm text-gray-400">{rotation}°</span>
        </div>

        {/* Crop editor */}
        <div className="flex flex-col items-center gap-1.5">
          <ReactCrop
            crop={crop}
            onChange={(_, pc) => setCrop(pc)}
            aspect={shiftHeld ? 1 : undefined}
            style={{ maxHeight: "50vh" }}
          >
            <img
              src={previewUrl}
              alt="Edit"
              style={{ maxHeight: "50vh", maxWidth: "100%", display: "block" }}
            />
          </ReactCrop>
          <p className="text-xs text-gray-400 dark:text-gray-500">
            Drag to crop · Hold <kbd className="px-1 py-0.5 rounded bg-gray-100 dark:bg-gray-800 font-mono text-[10px]">shift</kbd> to constrain to square
          </p>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-2 justify-end pt-2 border-t border-gray-200 dark:border-gray-700">
          {isEdited && (
            <button
              onClick={handleReset}
              disabled={busy}
              className="px-3 py-2 text-sm text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg disabled:opacity-50 mr-auto"
            >
              {t.detail.resetToOriginal}
            </button>
          )}
          <button
            onClick={onClose}
            disabled={busy}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 rounded-lg hover:bg-gray-200 disabled:opacity-50"
          >
            {t.common.cancel}
          </button>
          <button
            onClick={handleSave}
            disabled={busy}
            className="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {saving ? "…" : t.detail.saveEdits}
          </button>
        </div>
      </div>
    </div>
  );
}
