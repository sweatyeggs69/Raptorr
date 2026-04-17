/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          "Inter",
          "ui-sans-serif",
          "system-ui",
          "-apple-system",
          "Segoe UI",
          "Roboto",
          "sans-serif",
        ],
        mono: [
          "JetBrains Mono",
          "ui-monospace",
          "SFMono-Regular",
          "Menlo",
          "monospace",
        ],
      },
      colors: {
        ink: {
          50: "#f6f7f8",
          100: "#ebedf0",
          200: "#d4d8de",
          300: "#adb4bd",
          400: "#7d8793",
          500: "#5b6573",
          600: "#444d59",
          700: "#363c46",
          800: "#24292f",
          900: "#16191d",
          950: "#0b0d10",
        },
        accent: {
          DEFAULT: "#1f7a5a",
          600: "#1f7a5a",
          700: "#18604a",
        },
      },
    },
  },
  plugins: [],
};
