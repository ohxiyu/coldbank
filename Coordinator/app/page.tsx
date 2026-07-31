import type { Metadata } from "next";
import { Coordinator } from "./coordinator";

export const metadata: Metadata = {
  title: "Coldbank · 比特币冷钱包",
  description: "用在线 iPhone 创建交易，用离线 iPhone 检查和签名。",
};

export default function Home() {
  return <Coordinator />;
}
