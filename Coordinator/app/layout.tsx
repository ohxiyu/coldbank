import type { Metadata, Viewport } from "next";
import { headers } from "next/headers";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host =
    requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host");
  const protocol =
    requestHeaders.get("x-forwarded-proto") ??
    (host?.startsWith("localhost") ? "http" : "https");
  const origin = host ? `${protocol}://${host}` : "https://coldbank.app";
  const description = "无需安装第三方钱包软件的 iPhone 比特币冷钱包协调器。";
  return {
    title: {
      default: "Coldbank · 比特币冷钱包",
      template: "%s · Coldbank",
    },
    description,
    applicationName: "Coldbank",
    manifest: "/manifest.webmanifest",
    appleWebApp: {
      capable: true,
      statusBarStyle: "black-translucent",
      title: "Coldbank",
    },
    formatDetection: { telephone: false },
    openGraph: {
      type: "website",
      siteName: "Coldbank",
      title: "在线创建交易。离线确认签名。",
      description,
      images: [{ url: `${origin}/og.png`, width: 1730, height: 909 }],
    },
    twitter: {
      card: "summary_large_image",
      title: "Coldbank",
      description,
      images: [`${origin}/og.png`],
    },
  };
}

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  themeColor: "#071810",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
