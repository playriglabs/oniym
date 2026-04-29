import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        "bg-base": "#0a0a0f",
        "bg-surface": "#0f0f1a",
        "bg-elevated": "#15152a",
        "border-dark": "#1e1e3a",
        "border-cyan": "rgba(133,239,255,0.2)",
        cyan: {
          DEFAULT: "#85efff",
          dim: "#14acc3",
          muted: "rgba(133,239,255,0.08)",
          glow: "rgba(133,239,255,0.15)",
        },
        "text-primary": "#f0f0ff",
        "text-secondary": "#8888aa",
        "text-muted": "#444466",
        error: "#ff6b8a",
        "error-muted": "rgba(255,107,138,0.08)",
        "success-muted": "rgba(133,239,255,0.06)",
      },
      fontFamily: {
        sans: ["var(--font-sans)", "system-ui", "sans-serif"],
        mono: ["var(--font-mono)", "monospace"],
      },
      boxShadow: {
        "cyan-sm": "0 0 0 1px rgba(133,239,255,0.25)",
        "cyan-md": "0 0 0 1px rgba(133,239,255,0.35), 0 0 20px rgba(133,239,255,0.08)",
        "cyan-lg": "0 0 0 1px rgba(133,239,255,0.4), 0 0 40px rgba(133,239,255,0.12)",
        card: "0 1px 3px rgba(0,0,0,0.4), 0 1px 0 rgba(255,255,255,0.03) inset",
      },
      keyframes: {
        "slide-up": {
          from: { transform: "translateY(16px)", opacity: "0" },
          to: { transform: "translateY(0)", opacity: "1" },
        },
        "fade-in": {
          from: { opacity: "0" },
          to: { opacity: "1" },
        },
        "search-pulse": {
          "0%, 100%": { boxShadow: "0 0 0 0 rgba(133,239,255,0)" },
          "50%": { boxShadow: "0 0 0 6px rgba(133,239,255,0)" },
        },
        marquee: {
          "0%": { transform: "translateX(0)" },
          "100%": { transform: "translateX(-50%)" },
        },
      },
      animation: {
        "slide-up": "slide-up 0.4s cubic-bezier(0.16,1,0.3,1) forwards",
        "fade-in": "fade-in 0.3s ease-out forwards",
        marquee: "marquee 30s linear infinite",
      },
    },
  },
  plugins: [],
};

export default config;
