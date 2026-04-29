import type { NextConfig } from "next";

const config: NextConfig = {
  transpilePackages: ["@oniym/sdk"],
  experimental: {
    optimizePackageImports: ["framer-motion"],
  },
};

export default config;
