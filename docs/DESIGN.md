# HOTFIX! Design (8-bit direction, Nov 2026)

The 16-bit look was dropped: the art couldn't be produced at the quality the user wants. New
direction: **8-bit, Shovel Knight / AVGN Adventures style**, 400x240, black outlines, limited
palette, sprites drawn in code (`tools/pixel8/`), so no Gemini or 3D pipeline is needed.
Mock-ups: `art/mockups/8bit/`.

## Genre
Action platformer with short "screen locks, fight a wave" arenas (mix of Shovel Knight and
a beat 'em up). Code Bro: walk, jump, punch combo; more moves come from upgrades.

## Story
Code Bro fights his way up the corporate ladder of Nexus Dynamics, one floor per stage.
Every stage boss is the next rung of the org chart. The final boss is the CEO. Beating him
makes him sign Code Bro's **early retirement with endless money** (ending).

| Stage | Floor | Boss |
|---|---|---|
| 1 | Dev floor (open space, night) | Team Leader |
| 2 | Team rooms | Group Leader |
| 3 | Product / meeting rooms | Director |
| 4 | Executive floor | VP |
| 5 | Boardroom penthouse | CEO |

Beaten ranks come back as regular (tougher) enemies on later floors.

## Enemies
- **Bugs:** crawl along floors and platforms, swarm; drop cash. Variants later: flying bug,
  bug that splits in two.
- **JIRA tickets:** floating blue tickets with "JIRA" written on them and angry eyes; drift
  toward you and swoop. Punch one = "CLOSED!". Variants: red BLOCKER tickets (tougher), epics (big, split into tickets).
- **PMs (project managers):** stand on high ground and throw tasks (sticky notes) in an
  arc. A hit = "NEW TASK!" and damage.
- **Team Leaders, Group Leaders, Directors, VPs:** as regular enemies after their boss stage.

## Money and upgrades
Enemies and JIRA tickets drop **cash ($)**. Spend it between stages (break room vending
machine / HR) on upgrades, e.g.:
- Max HP (coffee), attack power (mechanical keyboard), double jump (new sneakers), dash,
  charged punch, armor vs. tasks (noise-cancelling headphones), coin magnet.
Health pickups in levels: coffee, pizza.
