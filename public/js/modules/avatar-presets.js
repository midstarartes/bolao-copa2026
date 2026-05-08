const buildLegendAvatar = ({ name, code, from, to, accent }) => {
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" role="img" aria-label="${name}">
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="${from}" />
          <stop offset="100%" stop-color="${to}" />
        </linearGradient>
      </defs>
      <rect width="96" height="96" rx="48" fill="url(#bg)" />
      <circle cx="48" cy="29" r="16" fill="#f3d3b3" />
      <path d="M28 78c4-17 15-25 20-25s16 8 20 25" fill="${accent}" />
      <path d="M34 24c4-9 25-12 32 1-3-15-23-18-32-1Z" fill="#1f2937" opacity=".78" />
      <text x="48" y="88" text-anchor="middle" font-family="Arial, sans-serif" font-size="11" font-weight="700" fill="#ffffff">${code}</text>
    </svg>
  `;
  return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
};

export const avatarPresets = [
  { name: "Pelé", code: "PEL", from: "#0c7a43", to: "#19b46b", accent: "#f4c430" },
  { name: "Zidane", code: "ZIZ", from: "#123c8c", to: "#4f7cff", accent: "#f5f5f5" },
  { name: "Beckenbauer", code: "BEC", from: "#3d444f", to: "#7f8b99", accent: "#ffffff" },
  { name: "Ronaldo", code: "RON", from: "#173b8f", to: "#1eb4ff", accent: "#ffe047" },
  { name: "Ronaldinho", code: "DIN", from: "#7928ca", to: "#b56dff", accent: "#ffd447" },
  { name: "Kaká", code: "KAK", from: "#8b1e1e", to: "#ef4444", accent: "#ffffff" },
  { name: "Marta", code: "MAR", from: "#0d5c63", to: "#15aabf", accent: "#f8f9fa" },
  { name: "Romário", code: "ROM", from: "#0f5132", to: "#22c55e", accent: "#f8d84e" },
  { name: "Cafu", code: "CAF", from: "#5b3a00", to: "#d97706", accent: "#ffffff" },
  { name: "Iniesta", code: "INI", from: "#7c2d12", to: "#fb923c", accent: "#f8fafc" },
  { name: "Buffon", code: "BUF", from: "#1e293b", to: "#475569", accent: "#facc15" },
  { name: "Cristiano", code: "CR7", from: "#7f1d1d", to: "#dc2626", accent: "#f8fafc" },
].map((entry, index) => ({
  id: `preset-${index + 1}`,
  name: entry.name,
  code: entry.code,
  gradient: `linear-gradient(135deg, ${entry.from}, ${entry.to})`,
  imageUrl: buildLegendAvatar(entry),
}));
