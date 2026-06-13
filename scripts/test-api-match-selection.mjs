import assert from "node:assert/strict";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const syncHandler = require("../api/the-sports-sync.js");
const { findBestApiEventForMatch, getApiEventTeamMatchQuality } = syncHandler.__test;

const canadaBosnia = {
  id: "jogo-3",
  home_team: "Canada",
  away_team: "Bosnia and Herzegovina",
  home_code: "CAN",
  away_code: "BIH",
  starts_at: "2026-06-12T19:00:00.000Z",
};

const usaParaguayEvent = {
  strHomeTeam: "United States",
  strAwayTeam: "Paraguay",
  dateEvent: "2026-06-12",
  strTimestamp: "2026-06-12T20:00:00Z",
  intHomeScore: "2",
  intAwayScore: "1",
  strStatus: "FT",
};

const canadaBosniaEvent = {
  strHomeTeam: "Canada",
  strAwayTeam: "Bosnia and Herzegovina",
  dateEvent: "2026-06-12",
  strTimestamp: "2026-06-12T19:00:00Z",
  intHomeScore: "1",
  intAwayScore: "0",
  strStatus: "FT",
};

assert.equal(getApiEventTeamMatchQuality(canadaBosnia, usaParaguayEvent), "none");
assert.equal(findBestApiEventForMatch(canadaBosnia, [usaParaguayEvent]), null);
assert.equal(
  findBestApiEventForMatch(canadaBosnia, [usaParaguayEvent, canadaBosniaEvent]),
  canadaBosniaEvent
);

console.log("API match selection tests passed.");
