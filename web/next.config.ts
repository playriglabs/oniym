import type { NextConfig } from "next";

const config: NextConfig = {
  transpilePackages: ["@oniym/sdk"],
  images: {
    unoptimized: true,
  },
  experimental: {
    optimizePackageImports: ["framer-motion"],
  },
};

export default config;
