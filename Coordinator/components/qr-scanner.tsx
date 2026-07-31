"use client";

import QrScanner from "qr-scanner";
import { useEffect, useRef, useState } from "react";

interface QRScannerProps {
  open: boolean;
  title: string;
  hint: string;
  progress?: string;
  onResult(value: string): void;
  onClose(): void;
}

export function QRScanner({
  open,
  title,
  hint,
  progress,
  onResult,
  onClose,
}: QRScannerProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const scannerRef = useRef<QrScanner | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!open || !videoRef.current) return;
    setError("");
    const scanner = new QrScanner(
      videoRef.current,
      (result) => onResult(result.data),
      {
        preferredCamera: "environment",
        returnDetailedScanResult: true,
        maxScansPerSecond: 8,
        highlightScanRegion: true,
        highlightCodeOutline: true,
      },
    );
    scannerRef.current = scanner;
    scanner.start().catch(() => {
      setError("无法打开相机。请允许相机权限，或从照片中选择二维码。");
    });
    return () => {
      scanner.destroy();
      scannerRef.current = null;
    };
  }, [onResult, open]);

  async function scanFile(file?: File) {
    if (!file) return;
    try {
      const result = await QrScanner.scanImage(file, {
        returnDetailedScanResult: true,
      });
      onResult(result.data);
    } catch {
      setError("这张图片中没有识别到二维码。");
    }
  }

  if (!open) return null;
  return (
    <div className="scanner-backdrop" role="dialog" aria-modal="true">
      <section className="scanner-sheet">
        <header className="scanner-header">
          <div>
            <p className="eyebrow">光学传输</p>
            <h2>{title}</h2>
          </div>
          <button className="icon-button" onClick={onClose} aria-label="关闭扫码">
            ×
          </button>
        </header>
        <div className="camera-frame">
          <video ref={videoRef} muted playsInline />
          <div className="camera-corners" aria-hidden="true" />
        </div>
        <p className="scanner-hint">{progress || hint}</p>
        {error && <p className="error-message">{error}</p>}
        <label className="secondary-button file-button">
          从照片选择
          <input
            type="file"
            accept="image/*"
            onChange={(event) => scanFile(event.target.files?.[0])}
          />
        </label>
      </section>
    </div>
  );
}
