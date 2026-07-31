"use client";

import QRCode from "qrcode";
import { useEffect, useState } from "react";

export function AnimatedQR({ frames }: { frames: string[] }) {
  const [frameIndex, setFrameIndex] = useState(0);
  const [image, setImage] = useState("");
  const visibleIndex = frames.length ? frameIndex % frames.length : 0;

  useEffect(() => {
    if (frames.length < 2) return;
    const timer = window.setInterval(
      () => setFrameIndex((index) => (index + 1) % frames.length),
      450,
    );
    return () => window.clearInterval(timer);
  }, [frames]);

  useEffect(() => {
    let active = true;
    if (!frames[visibleIndex]) return;
    QRCode.toDataURL(frames[visibleIndex], {
      errorCorrectionLevel: "L",
      margin: 2,
      width: 720,
      color: { dark: "#08130f", light: "#ffffff" },
    }).then((value) => {
      if (active) setImage(value);
    });
    return () => {
      active = false;
    };
  }, [frames, visibleIndex]);

  return (
    <div className="qr-stage" aria-live="polite">
      {image ? (
        // A data URL produced in-browser cannot use the framework image optimizer.
        // eslint-disable-next-line @next/next/no-img-element
        <img
          className="qr-image"
          src={image}
          alt={`PSBT BBQr，第 ${visibleIndex + 1}/${frames.length} 帧`}
        />
      ) : (
        <div className="qr-placeholder">正在生成二维码…</div>
      )}
      <div className="qr-progress">
        <span>BBQr · PSBT</span>
        <strong>
          {visibleIndex + 1} / {frames.length}
        </strong>
      </div>
    </div>
  );
}
