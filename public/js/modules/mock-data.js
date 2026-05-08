export const avatarPresets = [
  ["#0f766e", "#14b8a6", "⚽"],
  ["#0c4a6e", "#0284c7", "🥅"],
  ["#7c2d12", "#ea580c", "🏆"],
  ["#3f6212", "#84cc16", "🎯"],
  ["#6d28d9", "#9333ea", "🔥"],
  ["#9a3412", "#fb923c", "🦁"],
  ["#14532d", "#22c55e", "🌟"],
  ["#991b1b", "#ef4444", "🚀"],
  ["#1e3a8a", "#2563eb", "🧤"],
  ["#365314", "#65a30d", "👟"],
  ["#831843", "#ec4899", "🎉"],
  ["#164e63", "#06b6d4", "🟦"],
  ["#4a044e", "#c026d3", "🟣"],
  ["#78350f", "#f59e0b", "🟨"],
  ["#0f172a", "#475569", "🦅"],
  ["#14532d", "#16a34a", "🌍"],
  ["#172554", "#4f46e5", "🎖️"],
  ["#064e3b", "#10b981", "🟢"],
  ["#7f1d1d", "#dc2626", "🔴"],
  ["#713f12", "#eab308", "⭐"],
].map(([from, to, emoji], index) => ({
  id: `preset-${index + 1}`,
  emoji,
  gradient: `linear-gradient(135deg, ${from}, ${to})`,
}));

export const MOCK_DATA_VERSION = "v6-coins-mechanics";

const flagCodeByFifaCode = {
  MEX: "mx",
  KOR: "kr",
  RSA: "za",
  CZE: "cz",
  CAN: "ca",
  BIH: "ba",
  QAT: "qa",
  SUI: "ch",
  BRA: "br",
  HAI: "ht",
  MAR: "ma",
  SCO: "gb-sct",
  USA: "us",
  AUS: "au",
  PAR: "py",
  TUR: "tr",
  CIV: "ci",
  CUW: "cw",
  ECU: "ec",
  GER: "de",
  JPN: "jp",
  NED: "nl",
  SWE: "se",
  TUN: "tn",
  BEL: "be",
  EGY: "eg",
  IRN: "ir",
  NZL: "nz",
  CPV: "cv",
  KSA: "sa",
  ESP: "es",
  URU: "uy",
  FRA: "fr",
  IRQ: "iq",
  NOR: "no",
  SEN: "sn",
  ALG: "dz",
  ARG: "ar",
  AUT: "at",
  JOR: "jo",
  COL: "co",
  COD: "cd",
  POR: "pt",
  UZB: "uz",
  CRO: "hr",
  ENG: "gb-eng",
  GHA: "gh",
  PAN: "pa",
};

const buildFlagUrl = (flagCode) => (flagCode ? `https://flagcdn.com/${flagCode}.svg` : "");

const enrichSelection = (team, group) => {
  const flagCode = flagCodeByFifaCode[team.code] || "";
  return {
    ...team,
    group,
    flagCode,
    flagUrl: buildFlagUrl(flagCode),
  };
};

// Base oficial estruturada a partir das paginas da FIFA:
// - teams: lista de selecoes participantes
// - standings: composicao dos grupos
// - scores-fixtures: confrontos e agenda da fase de grupos
// Quando a FIFA publicar novas atualizacoes, basta substituir este arquivo.
export const officialWorldCupGroups = [
  {
    group: "A",
    teams: [
      { name: "México", code: "MEX", flag: "🇲🇽" },
      { name: "Coreia do Sul", code: "KOR", flag: "🇰🇷" },
      { name: "África do Sul", code: "RSA", flag: "🇿🇦" },
      { name: "Tchéquia", code: "CZE", flag: "🇨🇿" },
    ],
  },
  {
    group: "B",
    teams: [
      { name: "Canadá", code: "CAN", flag: "🇨🇦" },
      { name: "Bósnia e Herzegovina", code: "BIH", flag: "🇧🇦" },
      { name: "Catar", code: "QAT", flag: "🇶🇦" },
      { name: "Suíça", code: "SUI", flag: "🇨🇭" },
    ],
  },
  {
    group: "C",
    teams: [
      { name: "Brasil", code: "BRA", flag: "🇧🇷" },
      { name: "Haiti", code: "HAI", flag: "🇭🇹" },
      { name: "Marrocos", code: "MAR", flag: "🇲🇦" },
      { name: "Escócia", code: "SCO", flag: "🏴" },
    ],
  },
  {
    group: "D",
    teams: [
      { name: "Estados Unidos", code: "USA", flag: "🇺🇸" },
      { name: "Austrália", code: "AUS", flag: "🇦🇺" },
      { name: "Paraguai", code: "PAR", flag: "🇵🇾" },
      { name: "Turquia", code: "TUR", flag: "🇹🇷" },
    ],
  },
  {
    group: "E",
    teams: [
      { name: "Costa do Marfim", code: "CIV", flag: "🇨🇮" },
      { name: "Curaçao", code: "CUW", flag: "🇨🇼" },
      { name: "Equador", code: "ECU", flag: "🇪🇨" },
      { name: "Alemanha", code: "GER", flag: "🇩🇪" },
    ],
  },
  {
    group: "F",
    teams: [
      { name: "Japão", code: "JPN", flag: "🇯🇵" },
      { name: "Holanda", code: "NED", flag: "🇳🇱" },
      { name: "Suécia", code: "SWE", flag: "🇸🇪" },
      { name: "Tunísia", code: "TUN", flag: "🇹🇳" },
    ],
  },
  {
    group: "G",
    teams: [
      { name: "Bélgica", code: "BEL", flag: "🇧🇪" },
      { name: "Egito", code: "EGY", flag: "🇪🇬" },
      { name: "Irã", code: "IRN", flag: "🇮🇷" },
      { name: "Nova Zelândia", code: "NZL", flag: "🇳🇿" },
    ],
  },
  {
    group: "H",
    teams: [
      { name: "Cabo Verde", code: "CPV", flag: "🇨🇻" },
      { name: "Arábia Saudita", code: "KSA", flag: "🇸🇦" },
      { name: "Espanha", code: "ESP", flag: "🇪🇸" },
      { name: "Uruguai", code: "URU", flag: "🇺🇾" },
    ],
  },
  {
    group: "I",
    teams: [
      { name: "França", code: "FRA", flag: "🇫🇷" },
      { name: "Iraque", code: "IRQ", flag: "🇮🇶" },
      { name: "Noruega", code: "NOR", flag: "🇳🇴" },
      { name: "Senegal", code: "SEN", flag: "🇸🇳" },
    ],
  },
  {
    group: "J",
    teams: [
      { name: "Argélia", code: "ALG", flag: "🇩🇿" },
      { name: "Argentina", code: "ARG", flag: "🇦🇷" },
      { name: "Áustria", code: "AUT", flag: "🇦🇹" },
      { name: "Jordânia", code: "JOR", flag: "🇯🇴" },
    ],
  },
  {
    group: "K",
    teams: [
      { name: "Colômbia", code: "COL", flag: "🇨🇴" },
      { name: "Congo DR", code: "COD", flag: "🇨🇩" },
      { name: "Portugal", code: "POR", flag: "🇵🇹" },
      { name: "Uzbequistão", code: "UZB", flag: "🇺🇿" },
    ],
  },
  {
    group: "L",
    teams: [
      { name: "Croácia", code: "CRO", flag: "🇭🇷" },
      { name: "Inglaterra", code: "ENG", flag: "🏴" },
      { name: "Gana", code: "GHA", flag: "🇬🇭" },
      { name: "Panamá", code: "PAN", flag: "🇵🇦" },
    ],
  },
].map((entry) => ({
  ...entry,
  teams: entry.teams.map((team) => enrichSelection(team, entry.group)),
}));

export const worldCupSelections = officialWorldCupGroups.flatMap((entry) => entry.teams);

const officialGroupFixtures = [
  ["group-A-1", 1, "A", "México", "África do Sul", "2026-06-11T18:00:00Z", "Estádio da Cidade do México", "Cidade do México"],
  ["group-A-2", 2, "A", "Coreia do Sul", "Tchéquia", "2026-06-11T22:00:00Z", "Estádio Guadalajara", "Guadalajara"],
  ["group-B-1", 3, "B", "Canadá", "Bósnia e Herzegovina", "2026-06-12T18:00:00Z", "Estádio de Toronto", "Toronto"],
  ["group-D-1", 4, "D", "Estados Unidos", "Paraguai", "2026-06-12T22:00:00Z", "Estádio de Los Angeles", "Los Angeles"],
  ["group-C-1", 5, "C", "Haiti", "Escócia", "2026-06-13T16:00:00Z", "Estádio de Boston", "Boston"],
  ["group-D-2", 6, "D", "Austrália", "Turquia", "2026-06-13T19:00:00Z", "BC Place Vancouver", "Vancouver"],
  ["group-C-2", 7, "C", "Brasil", "Marrocos", "2026-06-13T22:00:00Z", "Estádio New York New Jersey", "Nova York / Nova Jersey"],
  ["group-B-2", 8, "B", "Catar", "Suíça", "2026-06-13T23:00:00Z", "Estádio da Baía de São Francisco", "São Francisco"],
  ["group-E-1", 9, "E", "Costa do Marfim", "Equador", "2026-06-14T16:00:00Z", "Estádio da Filadélfia", "Filadélfia"],
  ["group-E-2", 10, "E", "Alemanha", "Curaçao", "2026-06-14T20:00:00Z", "Estádio de Houston", "Houston"],
  ["group-F-1", 11, "F", "Holanda", "Japão", "2026-06-14T22:00:00Z", "Estádio de Dallas", "Dallas"],
  ["group-F-2", 12, "F", "Suécia", "Tunísia", "2026-06-14T23:00:00Z", "Estádio Monterrey", "Monterrey"],
  ["group-H-1", 13, "H", "Arábia Saudita", "Uruguai", "2026-06-15T16:00:00Z", "Estádio de Miami", "Miami"],
  ["group-H-2", 14, "H", "Espanha", "Cabo Verde", "2026-06-15T19:00:00Z", "Estádio de Atlanta", "Atlanta"],
  ["group-G-1", 15, "G", "Irã", "Nova Zelândia", "2026-06-15T22:00:00Z", "Estádio de Los Angeles", "Los Angeles"],
  ["group-G-2", 16, "G", "Bélgica", "Egito", "2026-06-15T23:00:00Z", "Estádio de Seattle", "Seattle"],
  ["group-I-1", 17, "I", "França", "Senegal", "2026-06-16T18:00:00Z", "Estádio New York New Jersey", "Nova York / Nova Jersey"],
  ["group-I-2", 18, "I", "Iraque", "Noruega", "2026-06-16T22:00:00Z", "Estádio de Boston", "Boston"],
  ["group-J-1", 19, "J", "Argentina", "Argélia", "2026-06-16T23:00:00Z", "Estádio de Kansas City", "Kansas City"],
  ["group-J-2", 20, "J", "Áustria", "Jordânia", "2026-06-17T01:00:00Z", "Estádio da Baía de São Francisco", "São Francisco"],
  ["group-L-1", 21, "L", "Gana", "Panamá", "2026-06-17T18:00:00Z", "Estádio de Toronto", "Toronto"],
  ["group-L-2", 22, "L", "Inglaterra", "Croácia", "2026-06-17T22:00:00Z", "Estádio de Dallas", "Dallas"],
  ["group-K-1", 23, "K", "Portugal", "Congo DR", "2026-06-17T23:00:00Z", "Estádio de Houston", "Houston"],
  ["group-K-2", 24, "K", "Uzbequistão", "Colômbia", "2026-06-18T01:00:00Z", "Estádio da Cidade do México", "Cidade do México"],
  ["group-A-3", 25, "A", "Tchéquia", "África do Sul", "2026-06-18T18:00:00Z", "Estádio de Atlanta", "Atlanta"],
  ["group-B-3", 26, "B", "Suíça", "Bósnia e Herzegovina", "2026-06-18T19:00:00Z", "Estádio de Los Angeles", "Los Angeles"],
  ["group-B-4", 27, "B", "Canadá", "Catar", "2026-06-18T22:00:00Z", "BC Place Vancouver", "Vancouver"],
  ["group-A-4", 28, "A", "México", "Coreia do Sul", "2026-06-18T23:00:00Z", "Estádio Guadalajara", "Guadalajara"],
  ["group-C-3", 29, "C", "Brasil", "Haiti", "2026-06-19T18:00:00Z", "Estádio da Filadélfia", "Filadélfia"],
  ["group-C-4", 30, "C", "Escócia", "Marrocos", "2026-06-19T22:00:00Z", "Estádio de Boston", "Boston"],
  ["group-D-3", 31, "D", "Turquia", "Paraguai", "2026-06-19T23:00:00Z", "Estádio da Baía de São Francisco", "São Francisco"],
  ["group-D-4", 32, "D", "Estados Unidos", "Austrália", "2026-06-20T01:00:00Z", "Estádio de Seattle", "Seattle"],
  ["group-E-3", 33, "E", "Alemanha", "Costa do Marfim", "2026-06-20T18:00:00Z", "Estádio de Toronto", "Toronto"],
  ["group-E-4", 34, "E", "Equador", "Curaçao", "2026-06-20T22:00:00Z", "Estádio de Kansas City", "Kansas City"],
  ["group-F-3", 35, "F", "Holanda", "Suécia", "2026-06-20T23:00:00Z", "Estádio de Houston", "Houston"],
  ["group-F-4", 36, "F", "Tunísia", "Japão", "2026-06-21T01:00:00Z", "Estádio Monterrey", "Monterrey"],
  ["group-H-3", 37, "H", "Uruguai", "Cabo Verde", "2026-06-21T18:00:00Z", "Estádio de Miami", "Miami"],
  ["group-H-4", 38, "H", "Espanha", "Arábia Saudita", "2026-06-21T22:00:00Z", "Estádio de Atlanta", "Atlanta"],
  ["group-G-3", 39, "G", "Bélgica", "Irã", "2026-06-21T23:00:00Z", "Estádio de Los Angeles", "Los Angeles"],
  ["group-G-4", 40, "G", "Nova Zelândia", "Egito", "2026-06-22T01:00:00Z", "BC Place Vancouver", "Vancouver"],
  ["group-I-3", 41, "I", "Noruega", "Senegal", "2026-06-22T18:00:00Z", "Estádio New York New Jersey", "Nova York / Nova Jersey"],
  ["group-I-4", 42, "I", "França", "Iraque", "2026-06-22T22:00:00Z", "Estádio da Filadélfia", "Filadélfia"],
  ["group-J-3", 43, "J", "Argentina", "Áustria", "2026-06-22T23:00:00Z", "Estádio de Dallas", "Dallas"],
  ["group-J-4", 44, "J", "Jordânia", "Argélia", "2026-06-23T01:00:00Z", "Estádio da Baía de São Francisco", "São Francisco"],
  ["group-L-3", 45, "L", "Inglaterra", "Gana", "2026-06-23T18:00:00Z", "Estádio de Boston", "Boston"],
  ["group-L-4", 46, "L", "Panamá", "Croácia", "2026-06-23T22:00:00Z", "Estádio de Toronto", "Toronto"],
  ["group-K-3", 47, "K", "Portugal", "Uzbequistão", "2026-06-23T23:00:00Z", "Estádio de Houston", "Houston"],
  ["group-K-4", 48, "K", "Colômbia", "Congo DR", "2026-06-24T01:00:00Z", "Estádio Guadalajara", "Guadalajara"],
  ["group-C-5", 49, "C", "Escócia", "Brasil", "2026-06-24T18:00:00Z", "Estádio de Miami", "Miami"],
  ["group-C-6", 50, "C", "Marrocos", "Haiti", "2026-06-24T22:00:00Z", "Estádio de Atlanta", "Atlanta"],
  ["group-B-5", 51, "B", "Suíça", "Canadá", "2026-06-24T23:00:00Z", "BC Place Vancouver", "Vancouver"],
  ["group-B-6", 52, "B", "Bósnia e Herzegovina", "Catar", "2026-06-25T01:00:00Z", "Estádio de Seattle", "Seattle"],
  ["group-A-5", 53, "A", "Tchéquia", "México", "2026-06-25T02:00:00Z", "Estádio da Cidade do México", "Cidade do México"],
  ["group-A-6", 54, "A", "África do Sul", "Coreia do Sul", "2026-06-25T02:00:00Z", "Estádio Monterrey", "Monterrey"],
  ["group-E-5", 55, "E", "Curaçao", "Costa do Marfim", "2026-06-25T18:00:00Z", "Estádio da Filadélfia", "Filadélfia"],
  ["group-E-6", 56, "E", "Equador", "Alemanha", "2026-06-25T22:00:00Z", "Estádio New York New Jersey", "Nova York / Nova Jersey"],
  ["group-F-5", 57, "F", "Japão", "Suécia", "2026-06-25T23:00:00Z", "Estádio de Dallas", "Dallas"],
  ["group-F-6", 58, "F", "Tunísia", "Holanda", "2026-06-26T01:00:00Z", "Estádio de Kansas City", "Kansas City"],
  ["group-D-5", 59, "D", "Turquia", "Estados Unidos", "2026-06-25T23:00:00Z", "Estádio de Los Angeles", "Los Angeles"],
  ["group-D-6", 60, "D", "Paraguai", "Austrália", "2026-06-26T01:00:00Z", "Estádio da Baía de São Francisco", "São Francisco"],
  ["group-I-5", 61, "I", "Noruega", "França", "2026-06-26T18:00:00Z", "Estádio de Boston", "Boston"],
  ["group-I-6", 62, "I", "Senegal", "Iraque", "2026-06-26T22:00:00Z", "Estádio de Toronto", "Toronto"],
  ["group-G-5", 63, "G", "Egito", "Irã", "2026-06-26T23:00:00Z", "Estádio de Seattle", "Seattle"],
  ["group-G-6", 64, "G", "Nova Zelândia", "Bélgica", "2026-06-27T01:00:00Z", "BC Place Vancouver", "Vancouver"],
  ["group-H-5", 65, "H", "Cabo Verde", "Arábia Saudita", "2026-06-26T23:00:00Z", "Estádio de Houston", "Houston"],
  ["group-H-6", 66, "H", "Uruguai", "Espanha", "2026-06-27T01:00:00Z", "Estádio Guadalajara", "Guadalajara"],
  ["group-L-5", 67, "L", "Panamá", "Inglaterra", "2026-06-27T18:00:00Z", "Estádio New York New Jersey", "Nova York / Nova Jersey"],
  ["group-L-6", 68, "L", "Croácia", "Gana", "2026-06-27T22:00:00Z", "Estádio da Filadélfia", "Filadélfia"],
  ["group-J-5", 69, "J", "Argélia", "Áustria", "2026-06-27T23:00:00Z", "Estádio de Kansas City", "Kansas City"],
  ["group-J-6", 70, "J", "Jordânia", "Argentina", "2026-06-28T01:00:00Z", "Estádio de Dallas", "Dallas"],
  ["group-K-5", 71, "K", "Colômbia", "Portugal", "2026-06-27T23:00:00Z", "Estádio de Miami", "Miami"],
  ["group-K-6", 72, "K", "Congo DR", "Uzbequistão", "2026-06-28T01:00:00Z", "Estádio de Atlanta", "Atlanta"],
];

const knockoutFixtures = [
  ["round32-1", 73, "round32", "16 avos de final", "2º do Grupo A", "2º do Grupo B", "2026-06-28T20:00:00Z", "Estádio de Los Angeles", "Los Angeles"],
  ["round32-2", 74, "round32", "16 avos de final", "1º do Grupo E", "Melhor 3º colocado", "2026-06-29T18:00:00Z", "Estádio de Boston", "Boston"],
  ["round32-3", 75, "round32", "16 avos de final", "1º do Grupo F", "2º do Grupo C", "2026-06-29T22:00:00Z", "Estádio Monterrey", "Monterrey"],
  ["round32-4", 76, "round32", "16 avos de final", "1º do Grupo C", "2º do Grupo F", "2026-06-30T01:00:00Z", "Estádio de Houston", "Houston"],
  ["round32-5", 77, "round32", "16 avos de final", "1º do Grupo I", "Melhor 3º colocado", "2026-06-30T18:00:00Z", "Estádio New York New Jersey", "Nova York / Nova Jersey"],
  ["round32-6", 78, "round32", "16 avos de final", "2º do Grupo E", "2º do Grupo I", "2026-06-30T22:00:00Z", "Estádio de Dallas", "Dallas"],
  ["round32-7", 79, "round32", "16 avos de final", "1º do Grupo A", "Melhor 3º colocado", "2026-07-01T01:00:00Z", "Estádio da Cidade do México", "Cidade do México"],
  ["round32-8", 80, "round32", "16 avos de final", "1º do Grupo L", "Melhor 3º colocado", "2026-07-01T18:00:00Z", "Estádio de Atlanta", "Atlanta"],
  ["round32-9", 81, "round32", "16 avos de final", "1º do Grupo D", "Melhor 3º colocado", "2026-07-01T22:00:00Z", "Estádio da Baía de São Francisco", "São Francisco"],
  ["round32-10", 82, "round32", "16 avos de final", "1º do Grupo G", "Melhor 3º colocado", "2026-07-02T01:00:00Z", "Estádio de Seattle", "Seattle"],
  ["round32-11", 83, "round32", "16 avos de final", "2º do Grupo K", "2º do Grupo L", "2026-07-02T18:00:00Z", "Estádio de Toronto", "Toronto"],
  ["round32-12", 84, "round32", "16 avos de final", "1º do Grupo H", "2º do Grupo J", "2026-07-02T22:00:00Z", "Estádio de Los Angeles", "Los Angeles"],
  ["round32-13", 85, "round32", "16 avos de final", "1º do Grupo B", "Melhor 3º colocado", "2026-07-03T01:00:00Z", "BC Place Vancouver", "Vancouver"],
  ["round32-14", 86, "round32", "16 avos de final", "1º do Grupo J", "2º do Grupo H", "2026-07-03T18:00:00Z", "Estádio de Miami", "Miami"],
  ["round32-15", 87, "round32", "16 avos de final", "1º do Grupo K", "Melhor 3º colocado", "2026-07-03T22:00:00Z", "Estádio de Kansas City", "Kansas City"],
  ["round32-16", 88, "round32", "16 avos de final", "2º do Grupo D", "2º do Grupo G", "2026-07-04T01:00:00Z", "Estádio de Dallas", "Dallas"],
  ["round16-1", 89, "round16", "Oitavas", "Vencedor J74", "Vencedor J77", "2026-07-04T18:00:00Z", "Estádio da Filadélfia", "Filadélfia"],
  ["round16-2", 90, "round16", "Oitavas", "Vencedor J73", "Vencedor J75", "2026-07-04T22:00:00Z", "Estádio de Houston", "Houston"],
  ["round16-3", 91, "round16", "Oitavas", "Vencedor J76", "Vencedor J78", "2026-07-05T18:00:00Z", "Estádio de Dallas", "Dallas"],
  ["round16-4", 92, "round16", "Oitavas", "Vencedor J79", "Vencedor J82", "2026-07-05T22:00:00Z", "Estádio de Atlanta", "Atlanta"],
  ["round16-5", 93, "round16", "Oitavas", "Vencedor J80", "Vencedor J84", "2026-07-06T18:00:00Z", "Estádio de Seattle", "Seattle"],
  ["round16-6", 94, "round16", "Oitavas", "Vencedor J81", "Vencedor J86", "2026-07-06T22:00:00Z", "Estádio de Boston", "Boston"],
  ["round16-7", 95, "round16", "Oitavas", "Vencedor J83", "Vencedor J87", "2026-07-07T18:00:00Z", "Estádio da Cidade do México", "Cidade do México"],
  ["round16-8", 96, "round16", "Oitavas", "Vencedor J85", "Vencedor J88", "2026-07-07T22:00:00Z", "Estádio New York New Jersey", "Nova York / Nova Jersey"],
  ["quarterfinal-1", 97, "quarterfinal", "Quartas de final", "Vencedor J89", "Vencedor J90", "2026-07-09T22:00:00Z", "Estádio de Los Angeles", "Los Angeles"],
  ["quarterfinal-2", 98, "quarterfinal", "Quartas de final", "Vencedor J91", "Vencedor J92", "2026-07-10T22:00:00Z", "Estádio de Kansas City", "Kansas City"],
  ["quarterfinal-3", 99, "quarterfinal", "Quartas de final", "Vencedor J93", "Vencedor J94", "2026-07-11T18:00:00Z", "Estádio de Miami", "Miami"],
  ["quarterfinal-4", 100, "quarterfinal", "Quartas de final", "Vencedor J95", "Vencedor J96", "2026-07-11T22:00:00Z", "Estádio de Boston", "Boston"],
  ["semifinal-1", 101, "semifinal", "Semifinal", "Vencedor J97", "Vencedor J98", "2026-07-14T22:00:00Z", "Estádio de Dallas", "Dallas"],
  ["semifinal-2", 102, "semifinal", "Semifinal", "Vencedor J99", "Vencedor J100", "2026-07-15T22:00:00Z", "Estádio de Atlanta", "Atlanta"],
  ["third-place-1", 103, "third-place", "3º lugar", "Perdedor SF1", "Perdedor SF2", "2026-07-18T20:00:00Z", "Estádio de Miami", "Miami"],
  ["final-1", 104, "final", "Final", "Vencedor SF1", "Vencedor SF2", "2026-07-19T19:00:00Z", "Estádio New York New Jersey", "Nova York / Nova Jersey"],
];

const findSelection = (name) => worldCupSelections.find((team) => team.name === name);

const isValidFixtureDate = (value) => {
  const parsedDate = new Date(value);
  return !Number.isNaN(parsedDate.getTime());
};

const isKnockoutPlaceholder = (value) => {
  if (typeof value !== "string") return false;
  const trimmedValue = value.trim();

  return (
    /^([12]º)\s+do\s+Grupo\s+[A-L]$/i.test(trimmedValue) ||
    /^Melhor\s+3º\s+colocado$/i.test(trimmedValue) ||
    /^(Vencedor|Perdedor)\s+(J\d+|SF\d+|QF\d+|O\d+|R\d+)$/i.test(trimmedValue) ||
    /^(Vencedor|Perdedor)\s+.+$/i.test(trimmedValue)
  );
};

const normalizeKnockoutPlaceholder = (value) => {
  if (typeof value !== "string") return value;

  return value
    .trim()
    .replace(/^1.\s+Grupo\s+/i, "1º do Grupo ")
    .replace(/^2.\s+Grupo\s+/i, "2º do Grupo ")
    .replace(/^1.\s+do\s+Grupo\s+/i, "1º do Grupo ")
    .replace(/^2.\s+do\s+Grupo\s+/i, "2º do Grupo ")
    .replace(/^Melhor\s+3.\s+colocado$/i, "Melhor 3º colocado")
    .replace(/^Melhor\s+3.\s+entre/i, "Melhor 3º entre")
    .replace(/^Vencedor\s+SF1$/i, "Vencedor da Semifinal 1")
    .replace(/^Vencedor\s+SF2$/i, "Vencedor da Semifinal 2")
    .replace(/^Perdedor\s+SF1$/i, "Perdedor da Semifinal 1")
    .replace(/^Perdedor\s+SF2$/i, "Perdedor da Semifinal 2");
};

const isRecognizedKnockoutPlaceholder = (value) => {
  if (typeof value !== "string") return false;
  const trimmedValue = normalizeKnockoutPlaceholder(value);

  return (
    /^[12].{0,2}\s+do\s+Grupo\s+[A-L]$/i.test(trimmedValue) ||
    /^Melhor\s+3.{0,2}\s+(colocado|entre)/i.test(trimmedValue) ||
    /^(Vencedor|Perdedor)\s+(da\s+Semifinal\s+[12]|J\d+|SF\d+|QF\d+|O\d+|R\d+)$/i.test(trimmedValue) ||
    /^(Vencedor|Perdedor)\s+.+$/i.test(trimmedValue)
  );
};

const buildFixtureObject = (fixture, isKnockout = false) => {
  if (isKnockout) {
    const [id, number, phase, phaseLabel, home, away, date, stadium, location] = fixture;
    return { id, number, phase, phaseLabel, group: null, home, away, date, stadium, location };
  }

  const [id, number, group, home, away, date, stadium, location] = fixture;
  return { id, number, phase: "group", phaseLabel: `Grupo ${group}`, group, home, away, date, stadium, location };
};

const mapFixture = (fixture, isKnockout = false) => {
  const fixtureData = buildFixtureObject(fixture, isKnockout);
  fixtureData.home = isKnockout ? normalizeKnockoutPlaceholder(fixtureData.home) : fixtureData.home;
  fixtureData.away = isKnockout ? normalizeKnockoutPlaceholder(fixtureData.away) : fixtureData.away;
  const homeIsPlaceholder = isRecognizedKnockoutPlaceholder(fixtureData.home);
  const awayIsPlaceholder = isRecognizedKnockoutPlaceholder(fixtureData.away);
  const homeSelection = homeIsPlaceholder ? null : findSelection(fixtureData.home);
  const awaySelection = awayIsPlaceholder ? null : findSelection(fixtureData.away);

  if (!homeSelection && !homeIsPlaceholder) {
    console.warn("mock-data: selecao mandante nao encontrada", fixtureData.id, fixtureData.home);
  }

  if (!awaySelection && !awayIsPlaceholder) {
    console.warn("mock-data: selecao visitante nao encontrada", fixtureData.id, fixtureData.away);
  }

  if (!isValidFixtureDate(fixtureData.date)) {
    console.warn("mock-data: data invalida no jogo", fixtureData.id, fixtureData.date);
  }

  return {
    id: fixtureData.id,
    number: fixtureData.number,
    phase: fixtureData.phase,
    phaseLabel: fixtureData.phaseLabel,
    group: fixtureData.group,
    home: fixtureData.home,
    away: fixtureData.away,
    date: fixtureData.date,
    homeTeam: fixtureData.home,
    awayTeam: fixtureData.away,
    homeCode: homeSelection?.code || fixtureData.home,
    awayCode: awaySelection?.code || fixtureData.away,
    startsAt: fixtureData.date,
    stadium: fixtureData.stadium,
    venue: fixtureData.stadium,
    location: fixtureData.location,
    status: "scheduled",
    scoreHome: null,
    scoreAway: null,
    extraTimeHome: null,
    extraTimeAway: null,
    winnerTeam: null,
  };
};

export const worldCupTemplateMatches = [
  ...officialGroupFixtures.map((fixture) => mapFixture(fixture)),
  ...knockoutFixtures.map((fixture) => mapFixture(fixture, true)),
];

export const mockMatches = [...worldCupTemplateMatches];

export const mockUsers = [
  {
    id: "u1",
    nickname: "capitao",
    realName: "Carlos Mendes",
    password: "1234",
    avatarType: "preset",
    avatarValue: "preset-1",
    isAdmin: true,
    isBlocked: false,
    previousRank: 2,
    coins: 10,
  },
  {
    id: "u2",
    nickname: "maria10",
    realName: "Maria Oliveira",
    password: "1234",
    avatarType: "preset",
    avatarValue: "preset-4",
    isAdmin: false,
    isBlocked: false,
    previousRank: 1,
    coins: 10,
  },
  {
    id: "u3",
    nickname: "pedrinho",
    realName: "Pedro Souza",
    password: "1234",
    avatarType: "preset",
    avatarValue: "preset-8",
    isAdmin: false,
    isBlocked: false,
    previousRank: 3,
    coins: 10,
  },
];

export const zebraTournamentOptions = [
  { group: "A", team: "África do Sul" },
  { group: "B", team: "Bósnia e Herzegovina" },
  { group: "C", team: "Haiti" },
  { group: "D", team: "Austrália" },
  { group: "E", team: "Curaçao" },
  { group: "F", team: "Tunísia" },
  { group: "G", team: "Nova Zelândia" },
  { group: "H", team: "Cabo Verde" },
  { group: "I", team: "Iraque" },
  { group: "J", team: "Jordânia" },
  { group: "K", team: "Congo DR" },
  { group: "L", team: "Panamá" },
];

export const mockSettings = {
  banner: {
    message: "Base da Copa 2026 atualizada com seleções, grupos e jogos oficiais da FIFA.",
    updatedAt: new Date().toISOString(),
  },
  bonusLockAt: new Date("2026-06-11T17:30:00Z").toISOString(),
  zebraTournamentOptions,
  bonusResults: {
    zebraStageByTeam: {
      "PanamÃ¡": "round16",
      "Ãfrica do Sul": "groupQualified",
    },
  },
};

export const mockBonusPredictions = {
  u1: {
    champion: "Brasil",
    runnerUp: "França",
    thirdPlace: "Argentina",
    fourthPlace: "Espanha",
    topScorer: "Mbappe",
    bestGroupStageTeam: "Brasil",
    totalGoals: 171,
    tournamentZebra: "Panamá",
  },
};

export const mockCoinEvents = [];

export const mockMinoritySnapshots = {};

export const mockPredictions = [
  { userId: "u1", matchId: "group-A-1", homeScore: 2, awayScore: 1, extraTimeHome: null, extraTimeAway: null, winnerTeam: null },
  { userId: "u1", matchId: "group-C-2", homeScore: 3, awayScore: 1, extraTimeHome: null, extraTimeAway: null, winnerTeam: null },
  { userId: "u2", matchId: "group-A-2", homeScore: 1, awayScore: 1, extraTimeHome: null, extraTimeAway: null, winnerTeam: null },
  { userId: "u2", matchId: "group-D-1", homeScore: 0, awayScore: 1, extraTimeHome: null, extraTimeAway: null, winnerTeam: null },
  { userId: "u3", matchId: "group-B-1", homeScore: 1, awayScore: 0, extraTimeHome: null, extraTimeAway: null, winnerTeam: null },
];

export const mockChatMessages = [
  {
    id: "c1",
    userId: "u1",
    nickname: "capitao",
    avatarType: "preset",
    avatarValue: "preset-1",
    message: "Atualizei a base com os grupos e confrontos oficiais da FIFA para 2026.",
    createdAt: new Date(Date.now() - 1000 * 60 * 22).toISOString(),
  },
  {
    id: "c2",
    userId: "u2",
    nickname: "maria10",
    avatarType: "preset",
    avatarValue: "preset-4",
    message: "Agora sim os dados da Copa estao alinhados com a fonte oficial.",
    createdAt: new Date(Date.now() - 1000 * 60 * 7).toISOString(),
  },
];

export const rulesSummary = {
  groupStage: [
    { label: "Placar exato", points: "+1" },
    { label: "Resultado correto", points: "+0,5" },
    { label: "Resultado errado", points: "-0,25" },
  ],
  knockout: [
    { label: "Placar exato no tempo normal", points: "+1,5" },
    { label: "Placar exato da prorrogacao", points: "+0,5" },
    { label: "Resultado correto do tempo normal", points: "+0,5" },
    { label: "Acertar quem avanca", points: "+0,5" },
    { label: "Errar quem avanca", points: "-0,5" },
  ],
  extras: [
    { label: "Campeao", points: "+5" },
    { label: "Vice", points: "+3" },
    { label: "3º lugar", points: "+2" },
    { label: "4º lugar", points: "+2" },
    { label: "Artilheiro", points: "+1,5" },
    { label: "Melhor campanha da fase de grupos", points: "+2" },
    { label: "Total de gols", points: "+1" },
  ],
  coinBuffs: [
    { label: "Empate protegido", points: "1🪙: se apostar empate e errar, não perde ponto" },
    { label: "Seguro de erro", points: "2🪙: se errar o jogo, zera a perda" },
    { label: "Anular palpite adversário", points: "3🪙: escolhe um rival e ele não pontua nesse jogo" },
    { label: "Pontuação x2", points: "4🪙: multiplica pontos ganhos e perdidos por 2" },
    { label: "Pontuação x3", points: "5🪙: multiplica pontos ganhos e perdidos por 3" },
  ],
  details: [
    "No mata-mata, a prorrogacao so entra quando houver empate no tempo normal.",
    "Os palpites fecham 30 minutos antes de cada jogo.",
    "Depois do fechamento, todos podem visualizar os palpites dos outros.",
    "Desempate do ranking: 1. Mais placares exatos 2. Mais acertos de resultado 3. Sorteio aleatorio.",
    "No total de gols, todos os empatados na menor diferenca recebem a pontuacao.",
    "Buffs por moedas so valem para palpites de jogos, nunca para palpites extras.",
    "Empate protegido, Seguro de erro, x2, x3 e Anular palpite adversario so podem ser usados ate as quartas de final.",
    "Semifinais e disputa de 3º lugar valem x2 automatico; a final vale x3 automatico.",
    "Quando houver multiplicador automatico, os buffs manuais de x2 e x3 ficam bloqueados.",
  ],
};
